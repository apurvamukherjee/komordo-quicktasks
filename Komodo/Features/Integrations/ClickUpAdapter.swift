import Foundation
import KomodoCore

/// ClickUp's API v2 with a personal token, which ClickUp takes bare in `Authorization`. Pushes go one request
/// each; then the list's statuses, its open tasks, and every task changed since the last poll are read.
struct ClickUpAdapter: ProviderAdapter {
    var token: String

    /// Every list the token can see, named by its place: "Space › Folder › List".
    func sources() async throws(ProviderError) -> [ProviderSource] {
        let teams = try await get("/team", [], as: ClickUp.Teams.self).teams
        var sources: [ProviderSource] = []
        for team in teams {
            let archived = [URLQueryItem(name: "archived", value: "false")]
            let prefix = teams.count > 1 ? "\(team.name) › " : ""
            for space in try await get("/team/\(team.id)/space", archived, as: ClickUp.Spaces.self).spaces {
                let folders = try await get("/space/\(space.id)/folder", archived, as: ClickUp.Folders.self).folders
                for folder in folders {
                    sources += folder.lists.map {
                        ProviderSource(id: $0.id, name: "\(prefix)\(space.name) › \(folder.name) › \($0.name)")
                    }
                }
                let lists = try await get("/space/\(space.id)/list", archived, as: ClickUp.Lists.self).lists
                sources += lists.map { ProviderSource(id: $0.id, name: "\(prefix)\(space.name) › \($0.name)") }
            }
        }
        return sources
    }

    func sync(
        _ pushes: [ExternalSync.Push], links: [ExternalLink], connection: ProviderConnection, calendar: Calendar
    ) async throws(ProviderError) -> ProviderAnswer {
        guard let listID = connection.sourceID else { throw .unreadable }
        var current = connection
        current.statuses = ClickUp.statuses(try await get("/list/\(listID)", [], as: ClickUp.List.self).statuses)
        if current.userID == nil {
            current.userID = try await get("/user", [], as: ClickUp.UserAnswer.self).user.id.text
        }
        var outcomes: [ExternalSync.Outcome] = []
        for push in pushes {
            outcomes.append(try await send(push, listID: listID, connection: current, calendar: calendar))
        }
        let open = try await tasks(listID: listID, since: nil)
        var changed: [ClickUp.Task] = []
        if let cursor = connection.cursor { changed = try await tasks(listID: listID, since: cursor) }
        let merged = ClickUp.merge(open: open, changed: changed, cursor: connection.cursor)
        return ProviderAnswer(
            outcomes: outcomes,
            items: merged.tasks.map {
                ExternalItem($0, userID: current.userID, connection: current, calendar: calendar)
            }, isEverything: true, cursor: merged.cursor, userID: current.userID, statuses: current.statuses)
    }

    private func send(
        _ push: ExternalSync.Push, listID: String, connection: ProviderConnection, calendar: Calendar
    ) async throws(ProviderError) -> ExternalSync.Outcome {
        switch push {
        case .add(let task):
            let fields = Provider.clickup.shape(connection.dateMapping).fields
            let answer = try await call(
                "POST", "/list/\(listID)/task",
                body: ClickUp.fields(of: task, fields, connection: connection, calendar: calendar))
            guard (200..<300).contains(answer.status) else { return refusal(answer) }
            let created = try ProviderHTTP.decode(ClickUp.Task.self, from: answer.data)
            return .added(externalID: created.id, url: created.url.flatMap(URL.init))
        case .update(let externalID, let task, let changes):
            let body = ClickUp.fields(of: task, changes, connection: connection, calendar: calendar)
            guard !body.isEmpty else { return .accepted }
            let answer = try await call("PUT", "/task/\(externalID)", body: body)
            if answer.status == 404 { return .gone }
            return (200..<300).contains(answer.status) ? .accepted : refusal(answer)
        case .delete(let externalID):
            let answer = try await call("DELETE", "/task/\(externalID)")
            if answer.status == 404 { return .gone }
            return (200..<300).contains(answer.status) ? .accepted : refusal(answer)
        }
    }

    private func refusal(_ answer: (data: Data, status: Int)) -> ExternalSync.Outcome {
        let failure = try? JSONDecoder().decode(ClickUp.Failure.self, from: answer.data)
        return .refused(failure?.err ?? "ClickUp answered \(answer.status)")
    }

    /// Every page of one read; a poll stops at 20 pages, 2,000 tasks, rather than run away.
    private func tasks(listID: String, since: String?) async throws(ProviderError) -> [ClickUp.Task] {
        var tasks: [ClickUp.Task] = []
        for page in 0..<20 {
            let answer = try await get(
                "/list/\(listID)/task", ClickUp.tasksQuery(since: since, page: page), as: ClickUp.TaskPage.self)
            tasks += answer.tasks
            if answer.lastPage != false || answer.tasks.isEmpty { break }
        }
        return tasks
    }

    private func get<Payload: Decodable>(
        _ path: String, _ query: [URLQueryItem], as type: Payload.Type
    ) async throws(ProviderError) -> Payload {
        let answer = try await call("GET", path, query: query)
        guard answer.status == 200 else { throw .server(answer.status) }
        return try ProviderHTTP.decode(type, from: answer.data)
    }

    private func call(
        _ method: String, _ path: String, query: [URLQueryItem] = [], body: [String: JSONValue]? = nil
    ) async throws(ProviderError) -> (data: Data, status: Int) {
        guard var components = URLComponents(string: ClickUp.base + path) else { throw .unreadable }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw .unreadable }
        return try await ProviderHTTP.send(
            ProviderHTTP.request(
                url, method: method, headers: ["Authorization": token], body: body.map(JSONValue.object)))
    }
}
