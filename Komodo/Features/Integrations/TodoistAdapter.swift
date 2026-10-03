import Foundation
import KomodoCore

/// Todoist through its one sync endpoint: Komodo's changes go up and Todoist's come down in the same request.
struct TodoistAdapter: ProviderAdapter {
    var token: String

    func sources() async throws(ProviderError) -> [ProviderSource] {
        let response = try await TodoistClient(token: token).sync(from: nil, resources: ["projects"])
        return response.projects.filter { !$0.isDeleted && !$0.isArchived }.map {
            ProviderSource(id: $0.id, name: $0.name)
        }
    }

    func sync(
        _ pushes: [ExternalSync.Push], links: [ExternalLink], connection: ProviderConnection, calendar: Calendar
    ) async throws(ProviderError) -> ProviderAnswer {
        guard let projectID = connection.sourceID else { throw .unreadable }
        let batch = Todoist.Batch(pushes, projectID: projectID)
        let response = try await TodoistClient(token: token).sync(
            from: connection.cursor, resources: ["items", "user"], commands: batch.commands)
        let userID = response.user?.id ?? connection.userID
        return ProviderAnswer(
            outcomes: batch.outcomes(response, linked: Set(links.map(\.externalID))),
            items: response.items(in: projectID, userID: userID, calendar: calendar), isEverything: response.fullSync,
            cursor: response.syncToken, userID: userID, statuses: nil)
    }
}
