import AppKit
import KomodoCore
import OSLog

/// One provider ⇄ one list (FEATURES §5): polled every 5 minutes while Komodo runs, with a catch-up at launch and
/// on wake, and backing off after a failure (ARCHITECTURE §4.4). Each sync sends Komodo's changes, then reads the
/// provider's; the adapter says how, and `ExternalSync` decides what.
@MainActor @Observable final class ProviderSync {
    let provider: Provider

    private(set) var isSyncing = false

    @ObservationIgnored private weak var store: BoardStore?
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var failures = 0
    /// Links for a board with no file, as in previews and captures.
    @ObservationIgnored private var unsavedLinks: [ExternalLink] = []
    private static let log = Logger(subsystem: "app.komodo.Komodo", category: "integrations")

    init(_ provider: Provider) {
        self.provider = provider
    }

    private var connectionID: String { provider.rawValue }
    private var name: String { provider.source.title }
    private var secret: KeychainSecret { .token(for: provider) }
    var isConnected: Bool { store?.settings[provider].isConnected == true }

    func attach(_ store: BoardStore) {
        self.store = store
        store.providerSyncs[provider] = self
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncIfAuto() }
        }
        #if DEBUG
            // `-connectTodoist YES` with `-sampleTodoist YES` connects the second sample source to the first list.
            if usesSamples, UserDefaults.standard.bool(forKey: "connect" + flagName), !isConnected,
                let listID = store.lists.first?.id
            {
                do {
                    try connect(token: "sample", source: SampleAdapter.sources(for: provider)[1], listID: listID)
                } catch {
                    Self.log.error("Couldn't connect the sample \(self.name, privacy: .public): \(error)")
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

    private func adapter(token: String) -> any ProviderAdapter {
        #if DEBUG
            if usesSamples, let store { return SampleAdapter(provider: provider, today: store.today) }
        #endif
        return provider.adapter(token: token)
    }

    // MARK: Connecting

    /// [Test] in the token sheet: what the token can sync with, which also proves it works.
    func sources(token: String) async throws(ProviderError) -> [ProviderSource] {
        try await adapter(token: token).sources()
    }

    /// [Save]: the token goes to the Keychain and the source starts syncing with the list from scratch.
    func connect(token: String, source: ProviderSource, listID: String) throws(KeychainError) {
        guard let store else { return }
        try secret.save(token.trimmingCharacters(in: .whitespacesAndNewlines))
        saveLinks([])
        var connection = store.settings[provider]
        connection.sourceID = source.id
        connection.sourceName = source.name
        connection.listID = listID
        connection.cursor = nil
        connection.userID = nil
        connection.connectedAt = store.now
        connection.lastSync = nil
        connection.problem = nil
        connection.statuses = []
        connection.statusTargets = [:]
        store.settings[provider] = connection
        Task { await sync() }
    }

    /// Stops syncing and forgets the token. Imported tasks stay, as ordinary tasks with their link.
    func disconnect() {
        guard let store else { return }
        do {
            try secret.remove()
        } catch {
            Self.log.error("Couldn't remove the \(self.name, privacy: .public) token: \(error)")
        }
        saveLinks([])
        store.settings[provider].sourceID = nil
        store.settings[provider].cursor = nil
        store.settings[provider].problem = nil
    }

    /// A new date mapping reads the same items differently. The links are first agreed with the tasks as they are,
    /// so the next pull takes the provider's dates rather than sending Komodo's back as edits.
    func setDateMapping(_ mapping: DateMapping) {
        guard let store, store.settings[provider].dateMapping != mapping else { return }
        let shape = provider.shape(mapping)
        let byID = Dictionary(store.tasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        saveLinks(
            loadLinks().map { link in
                var link = link
                if let task = byID[link.taskID] { link.snapshot = ExternalItem.snapshot(of: task, shape) }
                return link
            })
        store.settings[provider].dateMapping = mapping
        Task { await sync() }
    }

    // MARK: Syncing

    private func syncIfAuto() {
        guard store?.settings[provider].autoSync == true else { return }
        Task { await sync() }
    }

    /// Sync now, and each poll. Offline it waits for the network rather than failing (ARCHITECTURE §4.4).
    func sync() async {
        guard let store, let sourceID = store.settings[provider].sourceID, !isSyncing, Connectivity.shared.isOnline
        else { return }
        isSyncing = true
        defer { isSyncing = false }
        let token: String
        do {
            guard let saved = try secret.read() else { throw ProviderError.badToken }
            token = saved
        } catch let error as ProviderError {
            fail(error)
            return
        } catch {
            fail(nil, "The Keychain wouldn't give Komodo the \(name) token.")
            return
        }
        let adapter = adapter(token: token)
        let links = loadLinks()
        let before = context(for: store)
        let pushes =
            provider.isTwoWay
            ? ExternalSync.pushes(
                links: links, board: store.tasks, known: store.knownTaskIDs, trash: Set(store.trash.map(\.id)),
                context: before) : []
        let answer: ProviderAnswer
        do {
            answer = try await adapter.sync(
                pushes, links: links, connection: store.settings[provider], calendar: store.calendar)
        } catch {
            fail(error)
            return
        }
        // Disconnected or reconnected while the request was out.
        guard store.settings[provider].sourceID == sourceID else { return }

        if let statuses = answer.statuses { store.settings[provider].statuses = statuses }
        let context = context(for: store)
        let confirmed = ExternalSync.confirm(
            pushes, outcomes: answer.outcomes, links: links, board: store.tasks, context: context)
        let failuresBefore = store.storageFailures
        store.saveImported(confirmed.saved)
        let pulled = ExternalSync.pull(
            answer.items, links: confirmed.links, board: store.tasks, known: store.knownTaskIDs, context: context,
            isEverything: answer.isEverything)
        store.saveImported(pulled.saved)
        // Links to tasks that never reached the file would read as deletions after a relaunch, and with Sync deletes
        // on they'd delete those items at the provider. The old links still match the file, so they stay.
        guard store.storageFailures == failuresBefore else {
            fail(nil, "Komodo couldn't save the \(name) tasks. It'll try again on the next sync.")
            return
        }
        saveLinks(pulled.links)
        store.settings[provider].cursor = answer.cursor
        store.settings[provider].userID = answer.userID ?? store.settings[provider].userID
        store.settings[provider].lastSync = store.now
        store.settings[provider].problem = confirmed.refusals.first.map { "\(name) refused a change: \($0)" }
        failures = 0
    }

    private func context(for store: BoardStore) -> ExternalSync.Context {
        let connection = store.settings[provider]
        let listID = store.lists.first { $0.id == connection.listID }?.id ?? store.lists.first?.id ?? ""
        return ExternalSync.Context(
            connectionID: connectionID, source: provider.source, listID: listID, sourceTitle: connection.sourceName,
            onlyMine: connection.onlyMine, syncsDeletes: connection.syncsDeletes,
            connectedAt: connection.connectedAt ?? store.now, week: store.week, now: store.now,
            shape: provider.shape(connection.dateMapping))
    }

    private func fail(_ error: ProviderError?, _ message: String? = nil) {
        // The network went while the request was out: nothing needs attention, and it catches up once it's back.
        if error == .offline, !Connectivity.shared.isOnline { return }
        failures += 1
        let text = message ?? error?.message(for: provider) ?? ""
        Self.log.error("\(self.name, privacy: .public) sync failed: \(text)")
        store?.settings[provider].problem = text
    }

    // MARK: Links

    private func loadLinks() -> [ExternalLink] {
        guard let database = store?.database else { return unsavedLinks }
        do {
            return try database.links(for: connectionID)
        } catch {
            Self.log.error("Couldn't read \(self.name, privacy: .public) links: \(error)")
            return []
        }
    }

    private func saveLinks(_ links: [ExternalLink]) {
        guard let database = store?.database else {
            unsavedLinks = links
            return
        }
        do {
            try database.setLinks(links, for: connectionID)
        } catch {
            Self.log.error("Couldn't save \(self.name, privacy: .public) links: \(error)")
        }
    }
}

#if DEBUG
    extension ProviderSync {
        /// `Todoist`, `ClickUp` …, as the launch flags spell it: `-sampleTodoist`, `-connectClickUp`.
        var flagName: String { provider.source.title }

        /// `-sampleTodoist YES` (and so on for each provider) stands in for the provider, so the token sheet, the
        /// page and imported tasks can be captured and tried without a real account.
        var usesSamples: Bool { UserDefaults.standard.bool(forKey: "sample" + flagName) }
    }
#endif
