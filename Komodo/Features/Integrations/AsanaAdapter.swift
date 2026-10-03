import Foundation
import KomodoCore

/// Asana's REST API with a personal access token. Pushes go one request each, then the project is read whole:
/// its open tasks and those finished since the last poll, and the subtasks of open tasks that have any.
struct AsanaAdapter: ProviderAdapter {
    var token: String

    func sources() async throws(ProviderError) -> [ProviderSource] {
        let me = try await get(
            "/users/me", [URLQueryItem(name: "opt_fields", value: "workspaces.name")], as: Asana.Me.self)
        var sources: [ProviderSource] = []
        for workspace in me.data.workspaces {
            let projects = try await pages(
                "/projects",
                [
                    URLQueryItem(name: "workspace", value: workspace.gid),
                    URLQueryItem(name: "archived", value: "false"),
                    URLQueryItem(name: "opt_fields", value: "name"), URLQueryItem(name: "limit", value: "100"),
                ], as: Asana.Named.self)
            sources += projects.map {
                ProviderSource(
                    id: $0.gid, name: me.data.workspaces.count > 1 ? "\(workspace.name) › \($0.name)" : $0.name)
            }
        }
        return sources
    }

    func sync(
        _ pushes: [ExternalSync.Push], links: [ExternalLink], connection: ProviderConnection, calendar: Calendar
    ) async throws(ProviderError) -> ProviderAnswer {
        guard let projectID = connection.sourceID else { throw .unreadable }
        let started = Date.now
        var userID = connection.userID
        if userID == nil { userID = try await get("/users/me", [], as: Asana.Me.self).data.gid }
        var outcomes: [ExternalSync.Outcome] = []
        for push in pushes {
            outcomes.append(try await send(push, projectID: projectID, connection: connection, calendar: calendar))
        }
        // An hour's overlap, so a task finished while the last poll was out is still read.
        let since = connection.cursor.flatMap { ISO8601DateFormatter().date(from: $0) }?.addingTimeInterval(-3_600)
        let tasks = try await pages(
            "/tasks", Asana.tasksQuery(projectID: projectID, completedSince: since, offset: nil), as: Asana.Task.self)
        var items: [ExternalItem] = []
        for task in tasks {
            var subtasks: [Asana.Task]?
            if !task.completed { subtasks = (task.numSubtasks ?? 0) > 0 ? try await self.subtasks(of: task.gid) : [] }
            items.append(
                ExternalItem(
                    task, subtasks: subtasks, userID: userID, mapping: connection.dateMapping, calendar: calendar))
        }
        return ProviderAnswer(
            outcomes: outcomes, items: items, isEverything: true,
            cursor: ISO8601DateFormatter().string(from: started), userID: userID, statuses: nil)
    }

    // MARK: Pushes

    private func send(
        _ push: ExternalSync.Push, projectID: String, connection: ProviderConnection, calendar: Calendar
    ) async throws(ProviderError) -> ExternalSync.Outcome {
        let shape = Provider.asana.shape(connection.dateMapping)
        switch push {
        case .add(let task):
            var data = Asana.fields(of: task, shape.fields, mapping: connection.dateMapping, calendar: calendar)
            data["projects"] = .array([.string(projectID)])
            let answer = try await call(
                "POST", "/tasks", [URLQueryItem(name: "opt_fields", value: "permalink_url")], data: data)
            guard (200..<300).contains(answer.status) else { return refusal(answer) }
            let created = try ProviderHTTP.decode(Asana.Envelope<Asana.Task>.self, from: answer.data).data
            if let refused = try await matchSubtasks(of: created.gid, to: task.subtasks) { return refused }
            return .added(externalID: created.gid, url: created.permalinkURL.flatMap(URL.init))
        case .update(let externalID, let task, let changes):
            let data = Asana.fields(of: task, changes, mapping: connection.dateMapping, calendar: calendar)
            if !data.isEmpty {
                let answer = try await call("PUT", "/tasks/\(externalID)", [], data: data)
                if answer.status == 404 { return .gone }
                guard (200..<300).contains(answer.status) else { return refusal(answer) }
            }
            if changes.contains(.subtasks), let refused = try await matchSubtasks(of: externalID, to: task.subtasks) {
                return refused
            }
            return .accepted
        case .delete(let externalID):
            let answer = try await call("DELETE", "/tasks/\(externalID)", [])
            if answer.status == 404 { return .gone }
            return (200..<300).contains(answer.status) ? .accepted : refusal(answer)
        }
    }

    /// Brings the task's subtasks in Asana in line with Komodo's; nil once they match.
    private func matchSubtasks(
        of gid: String, to local: [Subtask]
    ) async throws(ProviderError) -> ExternalSync.Outcome? {
        guard !local.isEmpty else { return nil }
        for change in Asana.subtaskChanges(local: local, remote: try await subtasks(of: gid)) {
            let answer =
                if let subtask = change.gid {
                    try await call("PUT", "/tasks/\(subtask)", [], data: change.data)
                } else {
                    try await call("POST", "/tasks/\(gid)/subtasks", [], data: change.data)
                }
            guard (200..<300).contains(answer.status) else { return refusal(answer) }
        }
        return nil
    }

    private func refusal(_ answer: (data: Data, status: Int)) -> ExternalSync.Outcome {
        let failure = try? JSONDecoder().decode(Asana.Failure.self, from: answer.data)
        return .refused(failure?.errors.first?.message ?? "Asana answered \(answer.status)")
    }

    // MARK: Reading

    private func subtasks(of gid: String) async throws(ProviderError) -> [Asana.Task] {
        try await pages(
            "/tasks/\(gid)/subtasks",
            [URLQueryItem(name: "opt_fields", value: "name,completed"), URLQueryItem(name: "limit", value: "100")],
            as: Asana.Task.self)
    }

    /// Every page of a list; a poll stops at 20 pages, 2,000 tasks, rather than run away.
    private func pages<Item: Decodable & Sendable>(
        _ path: String, _ query: [URLQueryItem], as type: Item.Type
    ) async throws(ProviderError) -> [Item] {
        var items: [Item] = []
        var query = query
        for _ in 0..<20 {
            let page = try await get(path, query, as: [Item].self)
            items += page.data
            guard let offset = page.nextPage?.offset else { break }
            query.removeAll { $0.name == "offset" }
            query.append(URLQueryItem(name: "offset", value: offset))
        }
        return items
    }

    private func get<Payload: Decodable & Sendable>(
        _ path: String, _ query: [URLQueryItem], as type: Payload.Type
    ) async throws(ProviderError) -> Asana.Envelope<Payload> {
        let answer = try await call("GET", path, query)
        guard answer.status == 200 else { throw .server(answer.status) }
        return try ProviderHTTP.decode(Asana.Envelope<Payload>.self, from: answer.data)
    }

    private func call(
        _ method: String, _ path: String, _ query: [URLQueryItem], data: [String: JSONValue]? = nil
    ) async throws(ProviderError) -> (data: Data, status: Int) {
        guard var components = URLComponents(string: Asana.base + path) else { throw .unreadable }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw .unreadable }
        return try await ProviderHTTP.send(
            ProviderHTTP.request(
                url, method: method, headers: ["Authorization": "Bearer \(token)", "Accept": "application/json"],
                body: data.map { .object(["data": .object($0)]) }))
    }
}
