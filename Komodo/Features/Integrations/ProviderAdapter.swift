import Foundation
import KomodoCore

/// A project, database, team or list a token can see, as the token sheet offers it.
struct ProviderSource: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
}

/// What one sync brought back.
struct ProviderAnswer: Sendable {
    /// One per push, in order.
    var outcomes: [ExternalSync.Outcome]
    var items: [ExternalItem]
    /// `items` holds every open item, so a linked one missing from it was deleted.
    var isEverything: Bool
    var cursor: String?
    var userID: String?
    /// The source's statuses as read this time; nil when the provider has none.
    var statuses: [ProviderStatus]?
}

/// One provider's requests (ARCHITECTURE §8). The rules live in `ExternalSync`; an adapter only sends Komodo's
/// changes and reads the provider's, each in its own API.
protocol ProviderAdapter: Sendable {
    /// What the token can sync with; a token that works lists at least the call succeeding.
    func sources() async throws(ProviderError) -> [ProviderSource]

    /// Sends `pushes`, then reads what changed since `connection.cursor`. A refused push is an outcome, not a
    /// throw, so the rest still go through.
    func sync(
        _ pushes: [ExternalSync.Push], links: [ExternalLink], connection: ProviderConnection, calendar: Calendar
    ) async throws(ProviderError) -> ProviderAnswer
}

extension Provider {
    /// Nil for a provider whose client isn't built yet.
    func adapter(token: String) -> (any ProviderAdapter)? {
        let token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return switch self {
        case .todoist: TodoistAdapter(token: token)
        case .notion, .linear, .clickup, .asana: nil
        }
    }
}

extension KeychainSecret {
    /// A provider's personal token (ARCHITECTURE §8: their OAuth needs a secret an app can't keep). Debug builds
    /// take `-<provider>Token`, such as `-todoistToken`.
    static func token(for provider: Provider) -> KeychainSecret {
        KeychainSecret(
            service: "app.komodo.\(provider.rawValue)", account: "api-token", debugOverride: "\(provider.rawValue)Token"
        )
    }
}
