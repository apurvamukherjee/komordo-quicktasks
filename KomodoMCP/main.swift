import AppKit
import KomodoCore
import notify

// komodo-mcp (ARCHITECTURE §10): Claude Desktop, Claude Code and Raycast launch it and talk MCP over stdio. It
// opens Komodo's own database, and after each write it tells the running app to look again.

let environment = ProcessInfo.processInfo.environment
let databaseURL: URL
do {
    // KOMODO_DATABASE points it at a scratch file, as -databasePath does for the app.
    databaseURL =
        try environment["KOMODO_DATABASE"].map { URL(filePath: $0) }
        ?? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        .appending(path: "Komodo/Komodo.sqlite")
} catch {
    FileHandle.standardError.write(Data("komodo-mcp: no Application Support folder: \(error)\n".utf8))
    exit(1)
}

let database: AppDatabase
do {
    database = try AppDatabase.open(at: databaseURL)
} catch {
    FileHandle.standardError.write(Data("komodo-mcp: couldn't open \(databaseURL.path): \(error)\n".utf8))
    exit(1)
}

let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
let server = MCPServer(tools: KomodoTools(database: database), version: version)

while let line = readLine() {
    guard !line.isEmpty else { continue }
    let reply = server.handle(Data(line.utf8))
    if reply.changedBoard { notify_post(BoardChange.darwinNotification) }
    if let url = reply.opens { NSWorkspace.shared.open(url) }
    if let out = reply.line { FileHandle.standardOutput.write(out + Data("\n".utf8)) }
}
