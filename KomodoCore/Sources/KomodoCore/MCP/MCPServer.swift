import Foundation

/// The MCP side of `komodo-mcp` (FEATURES §5.1, ARCHITECTURE §10): JSON-RPC 2.0, one message per line over stdio.
/// It answers `initialize`, `ping`, `tools/list` and `tools/call`; the tools themselves are `KomodoTools`.
/// Hand-written rather than the MCP Swift SDK, since four methods don't justify a dependency.
public struct MCPServer: Sendable {
    /// What a line asks the helper to do besides answering.
    public struct Reply: Sendable {
        /// The response line, or nil for a notification.
        public var line: Data?
        /// A tool wrote to the database, so the app should look again.
        public var changedBoard = false
        /// `start_focus`'s `komodo://start?task=<id>`.
        public var opens: URL?
    }

    public static let protocolVersion = "2025-06-18"
    public let tools: KomodoTools
    public let version: String

    public init(tools: KomodoTools, version: String) {
        self.tools = tools
        self.version = version
    }

    public func handle(_ line: Data) -> Reply {
        guard let message = try? JSONDecoder().decode(JSONValue.self, from: line),
            let method = message["method"]?.string
        else {
            return Reply(line: Self.error(id: .null, code: -32700, message: "Parse error"))
        }
        // A message without an id is a notification, such as `notifications/initialized`, and gets no answer.
        guard let id = message["id"] else { return Reply(line: nil) }
        let params = message["params"] ?? [:]
        switch method {
        case "initialize":
            return Reply(
                line: Self.result(
                    id: id,
                    [
                        "protocolVersion": params["protocolVersion"] ?? .string(Self.protocolVersion),
                        "capabilities": ["tools": ["listChanged": false]],
                        "serverInfo": ["name": "komodo", "version": .string(version)],
                        "instructions": """
                        Komodo is the user's to-do list and focus timer on this Mac. Lists hold tasks in three \
                        columns: backlog, week (this week) and today. Call list_lists first for list IDs.
                        """,
                    ]))
        case "ping":
            return Reply(line: Self.result(id: id, [:]))
        case "tools/list":
            return Reply(line: Self.result(id: id, ["tools": .array(KomodoTools.definitions)]))
        case "tools/call":
            guard let name = params["name"]?.string else {
                return Reply(line: Self.error(id: id, code: -32602, message: "Missing tool name"))
            }
            let outcome = tools.call(name, arguments: params["arguments"] ?? [:])
            return Reply(
                line: Self.result(
                    id: id,
                    [
                        "content": [["type": "text", "text": .string(outcome.text)]],
                        "isError": .bool(outcome.isError),
                    ]),
                changedBoard: outcome.changedBoard, opens: outcome.opens)
        default:
            return Reply(line: Self.error(id: id, code: -32601, message: "Method not found: \(method)"))
        }
    }

    private static func result(id: JSONValue, _ result: JSONValue) -> Data {
        encode(["jsonrpc": "2.0", "id": id, "result": result])
    }

    private static func error(id: JSONValue, code: Int, message: String) -> Data {
        encode(["jsonrpc": "2.0", "id": id, "error": ["code": .int(code), "message": .string(message)]])
    }

    private static func encode(_ value: JSONValue) -> Data {
        let encoder = JSONEncoder()
        // One message per line: the encoder never inserts newlines without .prettyPrinted.
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        // Encoding a JSONValue can't fail: every case maps to plain JSON.
        return (try? encoder.encode(value)) ?? Data("{}".utf8)
    }
}
