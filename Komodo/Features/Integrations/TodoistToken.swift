import Foundation

extension KeychainSecret {
    /// The user's personal Todoist token (ARCHITECTURE §8: their OAuth needs a secret an app can't keep). Debug
    /// builds take `-todoistToken`.
    static let todoistToken = KeychainSecret(
        service: "app.komodo.todoist", account: "api-token", debugOverride: "todoistToken")
}
