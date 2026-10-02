import Foundation
import KomodoCore

/// Why a Todoist request failed, worded for the Integrations page.
enum TodoistError: Error, Equatable {
    case badToken
    case offline
    case rateLimited
    case server(Int)
    case unreadable

    var message: String {
        switch self {
        case .badToken: "Todoist didn't accept this token. Copy it again from Todoist's settings."
        case .offline: "Couldn't reach Todoist. Check your connection."
        case .rateLimited: "Todoist asked Komodo to slow down. It'll try again in a few minutes."
        case .server(let status): "Todoist answered \(status). Komodo will try again soon."
        case .unreadable: "Todoist sent something Komodo couldn't read."
        }
    }
}

/// Todoist's sync endpoint with the user's personal token (ARCHITECTURE §8). One request both sends Komodo's
/// changes and reads what changed since `syncToken`.
struct TodoistClient: Sendable {
    var token: String

    func sync(
        from syncToken: String?, resources: [String], commands: [Todoist.Command] = []
    ) async throws(TodoistError) -> Todoist.SyncResponse {
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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw .offline
        }
        switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200: break
        case 401, 403: throw .badToken
        case 429: throw .rateLimited
        case let status: throw .server(status)
        }
        do {
            return try JSONDecoder().decode(Todoist.SyncResponse.self, from: data)
        } catch {
            throw .unreadable
        }
    }

    /// Form fields escape everything but unreserved characters; a bare `+` would read as a space.
    private static func formEncoded(_ text: String) -> String {
        let unreserved = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? text
    }
}
