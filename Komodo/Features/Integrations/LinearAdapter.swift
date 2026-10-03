import Foundation
import KomodoCore

/// Linear's GraphQL API with a personal API key, which Linear takes bare in `Authorization`. Read only.
struct LinearAdapter: ProviderAdapter {
    var token: String

    /// A team syncs all its issues; a project under it narrows them.
    func sources() async throws(ProviderError) -> [ProviderSource] {
        let answer = try await send(Linear.Request(query: Linear.teamsQuery, variables: [:]), as: Linear.Teams.self)
        return answer.teams.nodes.flatMap { team -> [ProviderSource] in
            let projects = (team.projects?.nodes ?? []).filter { !$0.isFinished }
            return [ProviderSource(id: team.id, name: team.name)]
                + projects.map {
                    ProviderSource(
                        id: Linear.sourceID(team: team.id, project: $0.id), name: "\(team.name) › \($0.name)")
                }
        }
    }

    func sync(
        _ pushes: [ExternalSync.Push], links: [ExternalLink], connection: ProviderConnection, calendar: Calendar
    ) async throws(ProviderError) -> ProviderAnswer {
        guard let sourceID = connection.sourceID else { throw .unreadable }
        let open = try await issues(sourceID: sourceID, since: nil)
        var changed: [Linear.Issue] = []
        if let cursor = connection.cursor { changed = try await issues(sourceID: sourceID, since: cursor).issues }
        let merged = Linear.merge(open: open.issues, changed: changed, cursor: connection.cursor)
        var current = connection
        current.statuses = Linear.statuses(open.states)
        return ProviderAnswer(
            outcomes: [], items: merged.issues.map { ExternalItem($0, viewerID: open.viewerID, connection: current) },
            isEverything: true, cursor: merged.cursor, userID: open.viewerID, statuses: current.statuses)
    }

    /// Every page of one read; a poll stops at 20 pages, 2,000 issues, rather than run away.
    private func issues(
        sourceID: String, since: String?
    ) async throws(ProviderError) -> (issues: [Linear.Issue], states: [Linear.State], viewerID: String) {
        var issues: [Linear.Issue] = []
        var states: [Linear.State] = []
        var viewerID = ""
        var after: String?
        for _ in 0..<20 {
            let page = try await send(
                Linear.issuesRequest(sourceID: sourceID, since: since, after: after), as: Linear.Issues.self)
            issues += page.issues.nodes
            states = page.team?.states.nodes ?? states
            viewerID = page.viewer.id
            guard page.issues.pageInfo?.hasNextPage == true, let next = page.issues.pageInfo?.endCursor else { break }
            after = next
        }
        return (issues, states, viewerID)
    }

    private func send<Payload: Decodable & Sendable>(
        _ request: Linear.Request, as type: Payload.Type
    ) async throws(ProviderError) -> Payload {
        guard let url = Linear.url else { throw .unreadable }
        let body = JSONValue.object(["query": .string(request.query), "variables": .object(request.variables)])
        let answer = try await ProviderHTTP.send(
            ProviderHTTP.request(url, method: "POST", headers: ["Authorization": token], body: body))
        // GraphQL answers a bad query with 400 and its errors, which Komodo can't act on.
        guard answer.status == 200 else { throw answer.status == 400 ? .unreadable : .server(answer.status) }
        let response = try ProviderHTTP.decode(Linear.Response<Payload>.self, from: answer.data)
        guard let data = response.data else { throw .unreadable }
        return data
    }
}
