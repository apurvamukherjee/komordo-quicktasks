import Foundation
import KomodoCore

/// Todoist's sync endpoint with the user's personal token (ARCHITECTURE §8). One request both sends Komodo's
/// changes and reads what changed since `syncToken`.
struct TodoistClient: Sendable {
    var token: String

    func sync(
        from syncToken: String?, resources: [String], commands: [Todoist.Command] = []
    ) async throws(ProviderError) -> Todoist.SyncResponse {
        guard let url = Todoist.syncURL else { throw .unreadable }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "POST"
        request.setValue(
            "Bearer \(token.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let fields: [(String, String)]
        do {
            fields = [
                ("sync_token", syncToken ?? "*"),
                ("resource_types", String(decoding: try JSONEncoder().encode(resources), as: UTF8.self)),
                ("commands", String(decoding: try JSONEncoder().encode(commands), as: UTF8.self)),
            ]
        } catch {
            throw .unreadable
        }
        request.httpBody = Data(fields.map { "\($0)=\(Self.formEncoded($1))" }.joined(separator: "&").utf8)

        let answer = try await ProviderHTTP.send(request)
        guard answer.status == 200 else { throw .server(answer.status) }
        return try ProviderHTTP.decode(Todoist.SyncResponse.self, from: answer.data)
    }

    /// Form fields escape everything but unreserved characters; a bare `+` would read as a space.
    private static func formEncoded(_ text: String) -> String {
        let unreserved = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? text
    }
}
