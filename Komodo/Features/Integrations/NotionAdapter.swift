import Foundation
import KomodoCore

/// Notion's API with an internal integration's token. The database has to be shared with the integration first,
/// which is why the token sheet only lists the data sources Notion's search returns. Each sync reads the schema,
/// sends each push as its own request, then reads every page.
struct NotionAdapter: ProviderAdapter {
    var token: String

    func sources() async throws(ProviderError) -> [ProviderSource] {
        let sources = try await pages(
            "/search", body: ["filter": .object(["property": .string("object"), "value": .string("data_source")])],
            as: Notion.DataSource.self)
        return sources.map { ProviderSource(id: $0.id, name: $0.name) }
    }

    func sync(
        _ pushes: [ExternalSync.Push], links: [ExternalLink], connection: ProviderConnection, calendar: Calendar
    ) async throws(ProviderError) -> ProviderAnswer {
        guard let sourceID = connection.sourceID else { throw .unreadable }
        let source = try await read("GET", "/data_sources/\(sourceID)", as: Notion.DataSource.self)
        let schema = Notion.Schema(source.properties)
        var current = connection
        current.statuses = schema.statuses
        if current.userID == nil { current.userID = try await read("GET", "/users/me", as: Notion.Me.self).ownerID }
        var outcomes: [ExternalSync.Outcome] = []
        for push in pushes {
            outcomes.append(
                try await send(push, sourceID: sourceID, schema: schema, connection: current, calendar: calendar))
        }
        let pages = try await pages("/data_sources/\(sourceID)/query", body: [:], as: Notion.Page.self)
        return ProviderAnswer(
            outcomes: outcomes,
            items: pages.map {
                ExternalItem($0, schema: schema, ownerID: current.userID, connection: current, calendar: calendar)
            }, isEverything: true, cursor: ISO8601DateFormatter().string(from: .now), userID: current.userID,
            statuses: schema.status == nil ? nil : schema.statuses)
    }

    private func send(
        _ push: ExternalSync.Push, sourceID: String, schema: Notion.Schema, connection: ProviderConnection,
        calendar: Calendar
    ) async throws(ProviderError) -> ExternalSync.Outcome {
        switch push {
        case .add(let task):
            let fields = Provider.notion.shape(connection.dateMapping).fields
            let properties = Notion.properties(
                of: task, fields, schema: schema, connection: connection, calendar: calendar)
            let answer = try await call(
                "POST", "/pages",
                body: [
                    "parent": .object(["type": .string("data_source_id"), "data_source_id": .string(sourceID)]),
                    "properties": .object(properties),
                ])
            guard answer.status == 200 else { return refusal(answer) }
            let page = try ProviderHTTP.decode(Notion.Page.self, from: answer.data)
            return .added(externalID: page.id, url: page.url.flatMap(URL.init))
        case .update(let externalID, let task, let changes):
            let properties = Notion.properties(
                of: task, changes, schema: schema, connection: connection, calendar: calendar)
            guard !properties.isEmpty else { return .accepted }
            return outcome(try await call("PATCH", "/pages/\(externalID)", body: ["properties": .object(properties)]))
        case .delete(let externalID):
            return outcome(try await call("PATCH", "/pages/\(externalID)", body: ["in_trash": .bool(true)]))
        }
    }

    private func outcome(_ answer: (data: Data, status: Int)) -> ExternalSync.Outcome {
        if answer.status == 404 { return .gone }
        return answer.status == 200 ? .accepted : refusal(answer)
    }

    private func refusal(_ answer: (data: Data, status: Int)) -> ExternalSync.Outcome {
        let failure = try? JSONDecoder().decode(Notion.Failure.self, from: answer.data)
        return .refused(failure?.message ?? "Notion answered \(answer.status)")
    }

    /// Every page of a paged POST; a poll stops at 20 pages, 2,000 rows, rather than run away.
    private func pages<Item: Decodable & Sendable>(
        _ path: String, body: [String: JSONValue], as type: Item.Type
    ) async throws(ProviderError) -> [Item] {
        var items: [Item] = []
        var body = body
        body["page_size"] = .int(100)
        for _ in 0..<20 {
            let page = try await read("POST", path, body: body, as: Notion.List<Item>.self)
            items += page.results
            guard page.hasMore, let next = page.nextCursor else { break }
            body["start_cursor"] = .string(next)
        }
        return items
    }

    private func read<Payload: Decodable>(
        _ method: String, _ path: String, body: [String: JSONValue]? = nil, as type: Payload.Type
    ) async throws(ProviderError) -> Payload {
        let answer = try await call(method, path, body: body)
        guard answer.status == 200 else { throw .server(answer.status) }
        return try ProviderHTTP.decode(type, from: answer.data)
    }

    private func call(
        _ method: String, _ path: String, body: [String: JSONValue]? = nil
    ) async throws(ProviderError) -> (data: Data, status: Int) {
        guard let url = URL(string: Notion.base + path) else { throw .unreadable }
        return try await ProviderHTTP.send(
            ProviderHTTP.request(
                url, method: method,
                headers: ["Authorization": "Bearer \(token)", "Notion-Version": Notion.version],
                body: body.map(JSONValue.object)))
    }
}
