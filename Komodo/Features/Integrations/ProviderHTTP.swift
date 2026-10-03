import Foundation
import KomodoCore

/// Why a provider request failed, worded for the Integrations page.
enum ProviderError: Error, Equatable {
    case badToken
    case offline
    case rateLimited
    case server(Int)
    case unreadable

    func message(for provider: Provider) -> String {
        let name = provider.source.title
        return switch self {
        case .badToken: "\(name) didn't accept this token. Copy it again from \(name)'s settings."
        case .offline: "Couldn't reach \(name). Check your connection."
        case .rateLimited: "\(name) asked Komodo to slow down. It'll try again in a few minutes."
        case .server(let status): "\(name) answered \(status). Komodo will try again soon."
        case .unreadable: "\(name) sent something Komodo couldn't read."
        }
    }
}

/// The one way every provider client talks HTTP: a refused token, a rate limit and a server failure stop the
/// whole sync, while any other answer, a 404 or a refused change included, goes back to the client to judge.
enum ProviderHTTP {
    static func send(_ request: URLRequest) async throws(ProviderError) -> (data: Data, status: Int) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw .offline
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 401, 403: throw .badToken
        case 429: throw .rateLimited
        case 500...: throw .server(status)
        default: return (data, status)
        }
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws(ProviderError) -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw .unreadable
        }
    }

    /// A JSON request with the provider's headers.
    static func request(
        _ url: URL, method: String = "GET", headers: [String: String], body: JSONValue? = nil
    ) throws(ProviderError) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        for (field, value) in headers { request.setValue(value, forHTTPHeaderField: field) }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try JSONEncoder().encode(body)
            } catch {
                throw .unreadable
            }
        }
        return request
    }
}
