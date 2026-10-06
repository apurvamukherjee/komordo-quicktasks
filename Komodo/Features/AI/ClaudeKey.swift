import Foundation

extension KeychainSecret {
    /// The user's own Anthropic key (DESIGN_SYSTEM §13.23). Debug builds take `-claudeKey`.
    static let claudeKey = KeychainSecret(service: "app.komodo.claude", account: "api-key", debugOverride: "claudeKey")
}

/// Test on Settings ▸ AI: asks the Models API about the chosen model, which bills nothing, so a working key, a
/// refused one and a model the key can't use each get their own answer.
enum ClaudeKeyCheck {
    static func run(_ key: String, model: String) async -> SecureKeyField.TestState {
        guard await Connectivity.shared.isOnline else { return unreachable }
        guard let url = URL(string: "https://api.anthropic.com/v1/models/\(model)") else {
            return .invalid("Komodo couldn't build the request.")
        }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(key.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            switch (response as? HTTPURLResponse)?.statusCode {
            case 200: return .valid
            case 401, 403: return .invalid("Anthropic didn't accept this key. Copy it again from the Claude Console.")
            case 404: return .invalid("This key can't use \(model).")
            case let status:
                return .invalid("Anthropic answered \(status.map(String.init) ?? "oddly"). Try again soon.")
            }
        } catch {
            return unreachable
        }
    }

    private static let unreachable = SecureKeyField.TestState.invalid(
        "Couldn't reach Anthropic. Check your connection.")
}
