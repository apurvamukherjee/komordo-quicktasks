import AppKit
import KomodoCore
import OSLog

/// Todoist ⇄ one list (FEATURES §5): polled every 5 minutes while Komodo runs, with a catch-up at launch and on
/// wake, and backing off after a failure (ARCHITECTURE §4.4). Each sync is one request that sends Komodo's changes
/// and reads Todoist's.
@MainActor @Observable final class TodoistSync {
    static let connectionID = "todoist"

    private(set) var isSyncing = false

    @ObservationIgnored private weak var store: BoardStore?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var failures = 0
    /// Links for a board with no file, as in previews and captures.
    @ObservationIgnored private var unsavedLinks: [ExternalLink] = []
    private static let log = Logger(subsystem: "app.komodo.Komodo", category: "todoist")

    var isConnected: Bool { store?.settings[.todoist].sourceID != nil }

    func attach(_ store: BoardStore) {
        self.store = store
        store.todoistSync = self
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncIfAuto() }
        }
        #if DEBUG
            // `-connectTodoist YES` with `-sampleTodoist YES` connects the sample project to the first list.
            if Self.usesSamples, UserDefaults.standard.bool(forKey: "connectTodoist"), !isConnected,
                let listID = store.lists.first?.id
            {
                do {
                    try connect(token: "sample", project: Self.sampleProjects[1], listID: listID)
                } catch {
                    Self.log.error("Couldn't connect the sample project: \(error)")
                }
            }
        #endif
        loop = Task { [weak self] in
            while !Task.isCancelled {
                self?.syncIfAuto()
                // 5 minutes, or 1, 2, 4 … up to 30 after failures in a row.
                let failures = self?.failures ?? 0
                let minutes = failures == 0 ? 5 : min(30, 1 << (failures - 1))
                // Cancelled only when the app quits.
                guard (try? await Task.sleep(for: .seconds(minutes * 60), tolerance: .seconds(30))) != nil else {
                    return
                }
            }
        }
    }

    // MARK: Connecting

    /// [Test] in the token sheet: the account's open projects, which also proves the token works.
    static func projects(token: String) async throws(ProviderError) -> [Todoist.Project] {
        #if DEBUG
            if usesSamples { return sampleProjects }
        #endif
        let response = try await TodoistClient(token: token).sync(from: nil, resources: ["projects"])
        return response.projects.filter { !$0.isDeleted && !$0.isArchived }
    }

    /// [Save]: the token goes to the Keychain and the project starts syncing with the list from scratch.
    func connect(token: String, project: Todoist.Project, listID: String) throws(KeychainError) {
        guard let store else { return }
        try KeychainSecret.todoistToken.save(token.trimmingCharacters(in: .whitespacesAndNewlines))
        saveLinks([])
        store.settings[.todoist].sourceID = project.id
        store.settings[.todoist].sourceName = project.name
        store.settings[.todoist].listID = listID
        store.settings[.todoist].cursor = nil
        store.settings[.todoist].userID = nil
        store.settings[.todoist].connectedAt = store.now
        store.settings[.todoist].lastSync = nil
        store.settings[.todoist].problem = nil
        Task { await sync() }
    }

    /// Stops syncing and forgets the token. Imported tasks stay, as ordinary tasks with their link.
    func disconnect() {
        guard let store else { return }
        do {
            try KeychainSecret.todoistToken.remove()
        } catch {
            Self.log.error("Couldn't remove the Todoist token: \(error)")
        }
        saveLinks([])
        store.settings[.todoist].sourceID = nil
        store.settings[.todoist].cursor = nil
        store.settings[.todoist].problem = nil
    }

    // MARK: Syncing

    private func syncIfAuto() {
        guard store?.settings[.todoist].autoSync == true else { return }
        Task { await sync() }
    }

    /// Sync now, and each poll: Komodo's changes go up, then Todoist's come down in the same answer.
    func sync() async {
        guard let store, let projectID = store.settings[.todoist].sourceID, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        let token: String
        do {
            guard let saved = try KeychainSecret.todoistToken.read() else { throw ProviderError.badToken }
            token = saved
        } catch let error as ProviderError {
            fail(error)
            return
        } catch {
            fail(nil, "The Keychain wouldn't give Komodo the Todoist token.")
            return
        }
        let links = loadLinks()
        let pushes = ExternalSync.pushes(
            links: links, board: store.tasks, known: store.knownTaskIDs, trash: Set(store.trash.map(\.id)),
            context: context(for: store))
        let batch = Todoist.Batch(pushes, projectID: projectID)
        let response: Todoist.SyncResponse
        do {
            response = try await answer(
                token: token, from: store.settings[.todoist].cursor, commands: batch.commands)
        } catch {
            fail(error)
            return
        }
        // Disconnected or reconnected while the request was out.
        guard store.settings[.todoist].sourceID == projectID else { return }

        let context = context(for: store)
        let confirmed = ExternalSync.confirm(
            pushes, outcomes: batch.outcomes(response, linked: Set(links.map(\.externalID))), links: links,
            board: store.tasks, context: context)
        store.saveImported(confirmed.saved)
        let userID = response.user?.id ?? store.settings[.todoist].userID
        let pulled = ExternalSync.pull(
            response.items(in: projectID, userID: userID, calendar: store.calendar), links: confirmed.links,
            board: store.tasks, known: store.knownTaskIDs, context: context, isEverything: response.fullSync)
        store.saveImported(pulled.saved)
        saveLinks(pulled.links)
        store.settings[.todoist].cursor = response.syncToken
        store.settings[.todoist].userID = userID
        store.settings[.todoist].lastSync = store.now
        store.settings[.todoist].problem = confirmed.refusals.first.map { "Todoist refused a change: \($0)" }
        failures = 0
    }

    private func answer(
        token: String, from syncToken: String?, commands: [Todoist.Command]
    ) async throws(ProviderError) -> Todoist.SyncResponse {
        #if DEBUG
            if Self.usesSamples, let store {
                return Self.sampleResponse(commands: commands, from: syncToken, today: store.today)
            }
        #endif
        return try await TodoistClient(token: token).sync(
            from: syncToken, resources: ["items", "user"], commands: commands)
    }

    private func context(for store: BoardStore) -> ExternalSync.Context {
        let listID = store.lists.first { $0.id == store.settings[.todoist].listID }?.id ?? store.lists.first?.id ?? ""
        return ExternalSync.Context(
            connectionID: Self.connectionID, source: .todoist, listID: listID,
            sourceTitle: store.settings[.todoist].sourceName, onlyMine: store.settings[.todoist].onlyMine,
            syncsDeletes: store.settings[.todoist].syncsDeletes,
            connectedAt: store.settings[.todoist].connectedAt ?? store.now, week: store.week, now: store.now)
    }

    private func fail(_ error: ProviderError?, _ message: String? = nil) {
        failures += 1
        let text = message ?? error?.message(for: .todoist) ?? ""
        Self.log.error("Todoist sync failed: \(text)")
        store?.settings[.todoist].problem = text
    }

    // MARK: Links

    private func loadLinks() -> [ExternalLink] {
        guard let database = store?.database else { return unsavedLinks }
        do {
            return try database.links(for: Self.connectionID)
        } catch {
            Self.log.error("Couldn't read Todoist links: \(error)")
            return []
        }
    }

    private func saveLinks(_ links: [ExternalLink]) {
        guard let database = store?.database else {
            unsavedLinks = links
            return
        }
        do {
            try database.setLinks(links, for: Self.connectionID)
        } catch {
            Self.log.error("Couldn't save Todoist links: \(error)")
        }
    }
}

#if DEBUG
    extension TodoistSync {
        /// `-sampleTodoist YES` stands in for Todoist, so the token sheet, the page and imported tasks can be captured
        /// and tried without a real account.
        static var usesSamples: Bool { UserDefaults.standard.bool(forKey: "sampleTodoist") }

        static let sampleProjects = [
            Todoist.Project(id: "sample-inbox", name: "Inbox"),
            Todoist.Project(id: "sample-launch", name: "Komodo launch"),
            Todoist.Project(id: "sample-home", name: "Home"),
        ]

        /// The first sync reads three tasks, dated from the board's own day so `-sampleTime` places them as it
        /// would real ones; later syncs accept every command and change nothing.
        static func sampleResponse(
            commands: [Todoist.Command], from syncToken: String?, today: LocalDate
        ) -> Todoist.SyncResponse {
            let items =
                syncToken == nil
                ? [
                    Todoist.Item(
                        id: "sample-1", projectID: "sample-launch", content: "Write the launch post",
                        description: "Outline with Apurva", due: Todoist.Due(date: today.description + "T15:00:00"),
                        duration: Todoist.Duration(amount: 45, unit: "minute"), updatedAt: "2026-10-01T09:30:00Z"),
                    Todoist.Item(
                        id: "sample-2", projectID: "sample-launch", content: "Record the demo",
                        due: Todoist.Due(date: today.adding(days: 2, calendar: .current).description),
                        updatedAt: "2026-10-01T09:31:00Z"),
                    Todoist.Item(
                        id: "sample-3", projectID: "sample-launch", content: "Collect launch quotes",
                        updatedAt: "2026-10-01T09:32:00Z"),
                ] : []
            var json: [String: Any] = [
                "sync_token": "sample-\(UUID().uuidString)",
                "full_sync": syncToken == nil,
                "sync_status": Dictionary(uniqueKeysWithValues: commands.map { ($0.uuid, "ok") }),
                "temp_id_mapping": Dictionary(
                    uniqueKeysWithValues: commands.compactMap { $0.tempID }.map { ($0, "sample-\($0)") }),
                "user": ["id": "sample-user"],
            ]
            json["items"] = items.map(sampleJSON)
            do {
                let data = try JSONSerialization.data(withJSONObject: json)
                return try JSONDecoder().decode(Todoist.SyncResponse.self, from: data)
            } catch {
                preconditionFailure("Sample Todoist response doesn't decode: \(error)")
            }
        }

        private static func sampleJSON(_ item: Todoist.Item) -> [String: Any] {
            var json: [String: Any] = [
                "id": item.id, "project_id": item.projectID, "content": item.content,
                "description": item.description, "checked": false, "is_deleted": false,
                "updated_at": item.updatedAt ?? "",
            ]
            if let due = item.due { json["due"] = ["date": due.date, "is_recurring": false] }
            if let duration = item.duration { json["duration"] = ["amount": duration.amount, "unit": duration.unit] }
            return json
        }
    }
#endif
