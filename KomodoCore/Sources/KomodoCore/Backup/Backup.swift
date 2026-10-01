import Foundation
import GRDB

/// `manifest.json`: what a backup holds, read before any other file is touched (ARCHITECTURE §7).
public struct BackupManifest: Codable, Equatable, Sendable {
    public struct Counts: Codable, Equatable, Sendable {
        public var lists: Int
        public var tasks: Int
        public var sessions: Int
    }

    public var app: String
    public var appVersion: String
    public var schemaVersion: Int
    public var exportedAt: Date
    public var counts: Counts
}

/// Why a restore was refused (DESIGN_SYSTEM §13.22). Nothing is replaced when one is thrown.
public enum BackupError: Error, Equatable, Sendable {
    case notABackup
    case newerVersion
    case damaged
    /// A `.kbak` was opened without a password.
    case passwordRequired
    case wrongPassword
}

/// A backup unzipped into a temporary folder and checked: its manifest reads, its database passes SQLite's
/// integrity check and loads, and it's been migrated to this version's schema, ready to copy in.
public struct BackupArchive: Sendable {
    public var fileName: String
    public var manifest: BackupManifest
    let folder: URL
    let databaseURL: URL

    /// Removes the unzipped copy once the restore is done or cancelled.
    public func discard() throws { try FileManager.default.removeItem(at: folder) }
}

/// Zip export, restore checks and the automatic backups' folder (FEATURES §4.21, ARCHITECTURE §7).
public enum Backup {
    static let appName = "Komodo"
    static let manifestFile = "manifest.json"
    static let databaseFile = "komodo.sqlite"
    static let knownFiles: Set<String> = [manifestFile, databaseFile, "data.json", "tasks.csv", "sessions.csv"]
    static let prefix = "komodo-backup-"

    /// `komodo-backup-2026-09-26.zip`, with a suffix such as "before-restore" for the copies Komodo makes itself,
    /// and `.kbak` when it's password-protected.
    public static func fileName(
        on date: Date, calendar: Calendar, suffix: String? = nil, isProtected: Bool = false
    ) -> String {
        prefix + LocalDate(date, calendar: calendar).description + (suffix.map { "-" + $0 } ?? "") + "."
            + (isProtected ? BackupCrypto.fileExtension : "zip")
    }

    // MARK: Export

    /// Writes the whole database to `destination` as a zip, sealed as a `.kbak` when there's a password. Every
    /// file inside comes from one `VACUUM INTO` snapshot, so they agree with each other even while the app keeps
    /// writing.
    public static func export(
        _ database: AppDatabase, appVersion: String, to destination: URL, password: String? = nil,
        at now: Date = Date(), calendar: Calendar = .current
    ) throws {
        let files = FileManager.default
        let work = files.temporaryDirectory.appending(path: "komodo-export-\(UUID().uuidString)")
        defer { try? files.removeItem(at: work) }
        let folder = work.appending(path: destination.deletingPathExtension().lastPathComponent)
        try files.createDirectory(at: folder, withIntermediateDirectories: true)

        let snapshotURL = folder.appending(path: databaseFile)
        try database.writer.vacuum(into: snapshotURL.path)
        let snapshot = try DatabaseQueue(path: snapshotURL.path)
        let manifest = BackupManifest(
            app: appName, appVersion: appVersion, schemaVersion: AppDatabase.schemaVersion, exportedAt: now,
            counts: try snapshot.read(counts))
        try snapshot.read { db in
            try json(manifest).write(to: folder.appending(path: manifestFile))
            try tablesJSON(db).write(to: folder.appending(path: "data.json"))
            try Data(tasksCSV(db, calendar: calendar).utf8).write(to: folder.appending(path: "tasks.csv"))
            try Data(sessionsCSV(db, calendar: calendar).utf8).write(to: folder.appending(path: "sessions.csv"))
        }
        try snapshot.close()

        // Zipped beside the work folder first, so a failure never leaves half a zip at the destination.
        let zip = work.appending(path: destination.lastPathComponent)
        try run(
            "/usr/bin/ditto", ["-c", "-k", "--norsrc", "--noextattr", "--noacl", "--keepParent", folder.path, zip.path])
        if let password {
            try BackupCrypto.seal(Data(contentsOf: zip), password: password).write(to: zip)
        }
        if files.fileExists(atPath: destination.path) {
            _ = try files.replaceItemAt(destination, withItemAt: zip)
        } else {
            try files.moveItem(at: zip, to: destination)
        }
    }

    // MARK: Restore

    /// Checks a zip or `.kbak` without touching the current data. The file list is read before anything is
    /// unzipped, and only Komodo's own file names are accepted, so a crafted zip can't write outside the
    /// temporary folder.
    public static func open(_ file: URL, password: String? = nil) throws(BackupError) -> BackupArchive {
        var zip = file
        // Judged by its first bytes rather than its name, so a renamed .kbak still asks for the password.
        if let data = try? Data(contentsOf: file, options: .mappedIfSafe), BackupCrypto.isSealed(data) {
            guard let password else { throw .passwordRequired }
            zip = FileManager.default.temporaryDirectory.appending(path: "komodo-unsealed-\(UUID().uuidString).zip")
            let unsealed = try BackupCrypto.open(data, password: password)
            do {
                try unsealed.write(to: zip)
            } catch {
                throw .damaged
            }
        }
        defer { if zip != file { try? FileManager.default.removeItem(at: zip) } }
        let entries: [String]
        do {
            entries = try output("/usr/bin/zipinfo", ["-1", zip.path]).split(separator: "\n").map(String.init)
        } catch {
            throw .notABackup
        }
        guard let root = backupRoot(entries) else { throw .notABackup }

        let folder = FileManager.default.temporaryDirectory.appending(path: "komodo-restore-\(UUID().uuidString)")
        do {
            try run("/usr/bin/ditto", ["-x", "-k", zip.path, folder.path])
        } catch {
            throw .damaged
        }
        let contents = root.isEmpty ? folder : folder.appending(path: root)
        let manifest: BackupManifest
        do {
            manifest = try decoder.decode(
                BackupManifest.self, from: Data(contentsOf: contents.appending(path: manifestFile)))
        } catch {
            throw .notABackup
        }
        guard manifest.app == appName else { throw .notABackup }
        guard manifest.schemaVersion <= AppDatabase.schemaVersion else { throw .newerVersion }

        let databaseURL = contents.appending(path: databaseFile)
        do {
            let queue = try DatabaseQueue(path: databaseURL.path)
            let isNewer = try queue.read { db in
                guard try String.fetchOne(db, sql: "PRAGMA integrity_check") == "ok" else { throw BackupError.damaged }
                return try AppDatabase.migrator.hasBeenSuperseded(db)
            }
            if isNewer { throw BackupError.newerVersion }
            // Migrating the unzipped copy brings an older backup up to date before it's copied in.
            _ = try AppDatabase(queue).load()
            try queue.close()
        } catch let error as BackupError {
            throw error
        } catch {
            throw .damaged
        }
        return BackupArchive(
            fileName: file.lastPathComponent, manifest: manifest, folder: folder, databaseURL: databaseURL)
    }

    /// The folder the files sit in ("" for the zip's root), or nil when the list isn't a Komodo backup: only
    /// known names, at most one folder deep, and a manifest and database among them.
    static func backupRoot(_ entries: [String]) -> String? {
        var root: String?
        var names: Set<String> = []
        for entry in entries where !entry.isEmpty {
            let parts = entry.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
            // Finder's zips carry resource forks as `__MACOSX/…` and `._name`; ditto turns them back into
            // attributes rather than files, so they're skipped rather than refused.
            if parts.first == "__MACOSX" || parts.last?.hasPrefix("._") == true { continue }
            guard !parts.contains(".."), !parts.contains("."), !entry.hasPrefix("/") else { return nil }
            let isFolder = entry.hasSuffix("/")
            switch (parts.count, isFolder) {
            case (1, true):
                guard root == nil || root == parts[0] else { return nil }
                root = parts[0]
            case (1, false):
                guard root == nil || root == "" else { return nil }
                root = ""
                names.insert(parts[0])
            case (2, false):
                guard root == nil || root == parts[0] else { return nil }
                root = parts[0]
                names.insert(parts[1])
            default:
                return nil
            }
        }
        guard names.isSubset(of: knownFiles), names.contains(manifestFile), names.contains(databaseFile) else {
            return nil
        }
        return root
    }

    // MARK: Automatic backups

    /// Keeps the newest `count` of Komodo's zips in `folder` and deletes the rest. The date in the name sorts
    /// them, so a file copied in later can't jump the queue. Other files in the folder are left alone.
    @discardableResult
    public static func prune(_ folder: URL, keeping count: Int) throws -> [URL] {
        let zips = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix(prefix) && $0.pathExtension == "zip" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        let old = Array(zips.dropFirst(max(0, count)))
        for url in old { try FileManager.default.removeItem(at: url) }
        return old
    }

    // MARK: Files

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func json(_ manifest: BackupManifest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(manifest)
    }

    private static func counts(_ db: Database) throws -> BackupManifest.Counts {
        func count(_ table: String) throws -> Int { try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)") ?? 0 }
        return BackupManifest.Counts(
            lists: try count("lists"), tasks: try count("tasks"), sessions: try count("sessions"))
    }

    /// `data.json`: every table's rows as readable JSON. Notes appear as plain text; their RTF twin is binary and
    /// lives in `komodo.sqlite`.
    private static func tablesJSON(_ db: Database) throws -> Data {
        var tables: [String: [[String: Any]]] = [:]
        for table in ["lists", "tasks", "subtasks", "sessions", "preferences"] {
            tables[table] = try Row.fetchAll(db, sql: "SELECT * FROM \(table)").map { row in
                var object: [String: Any] = [:]
                for (column, value) in row {
                    switch value.storage {
                    case .null: object[column] = NSNull()
                    case .int64(let number): object[column] = number
                    case .double(let number): object[column] = number
                    case .string(let text): object[column] = text
                    case .blob: continue
                    }
                }
                return object
            }
        }
        return try JSONSerialization.data(withJSONObject: tables, options: [.prettyPrinted, .sortedKeys])
    }

    private static func tasksCSV(_ db: Database, calendar: Calendar) throws -> String {
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT t.id, l.name AS list, t.title, t.bucket, t.scheduled_date, t.scheduled_minute, t.estimate,
                  (SELECT SUM(COALESCE(s.ended_at, s.started_at) - s.started_at) FROM sessions s
                   WHERE s.task_id = t.id) AS taken,
                  t.completed_at, t.deleted_at, t.archived_at, t.created_at, t.notes
                FROM tasks t LEFT JOIN lists l ON l.id = t.list_id
                ORDER BY l.position, t.rank
                """)
        return CSV.document(
            header: [
                "id", "list", "title", "column", "status", "scheduled", "estimate_min", "time_taken_min",
                "completed_at", "created_at", "notes",
            ],
            rows: rows.map { row in
                let status =
                    switch (row["deleted_at"] as Double?, row["archived_at"] as Double?, row["completed_at"] as Double?)
                    {
                    case (.some, _, _): "trash"
                    case (nil, .some, _): "archived"
                    case (nil, nil, .some): "done"
                    case (nil, nil, nil): "open"
                    }
                let scheduled = [
                    row["scheduled_date"] as String?,
                    (row["scheduled_minute"] as Int?).map { String(format: "%02d:%02d", $0 / 60, $0 % 60) },
                ]
                .compactMap { $0 }.joined(separator: " ")
                return [
                    row["id"], row["list"] ?? "", row["title"], row["bucket"], status, scheduled,
                    CSV.minutes(row["estimate"]), CSV.minutes(row["taken"]),
                    CSV.timestamp(row["completed_at"], calendar: calendar),
                    CSV.timestamp(row["created_at"], calendar: calendar), row["notes"] ?? "",
                ]
            })
    }

    private static func sessionsCSV(_ db: Database, calendar: Calendar) throws -> String {
        let rows = try Row.fetchAll(
            db,
            sql: """
                SELECT s.task_id, t.title, l.name AS list, s.started_at, s.ended_at
                FROM sessions s JOIN tasks t ON t.id = s.task_id LEFT JOIN lists l ON l.id = t.list_id
                ORDER BY s.started_at
                """)
        return CSV.document(
            header: ["task_id", "task", "list", "started_at", "ended_at", "minutes"],
            rows: rows.map { row in
                let start: Double = row["started_at"]
                let end: Double? = row["ended_at"]
                return [
                    row["task_id"], row["title"], row["list"] ?? "", CSV.timestamp(start, calendar: calendar),
                    CSV.timestamp(end, calendar: calendar),
                    CSV.minutes(end.map { $0 - start }),
                ]
            })
    }

    // MARK: Tools

    private static func run(_ tool: String, _ arguments: [String]) throws { _ = try output(tool, arguments) }

    private static func output(_ tool: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(filePath: tool)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ToolError(tool: URL(filePath: tool).lastPathComponent, status: process.terminationStatus)
        }
        return String(decoding: data, as: UTF8.self)
    }
}

/// `ditto` or `zipinfo` exited with an error.
public struct ToolError: Error, Equatable, Sendable {
    public var tool: String
    public var status: Int32
}

extension AppDatabase {
    /// Bumped by each migration; a backup from a later schema is refused rather than half-read.
    public static var schemaVersion: Int { migrator.migrations.count }

    /// Copies a checked backup over everything in the open database with SQLite's online backup, so the store
    /// keeps its connection and nothing has to close or swap files.
    public func replaceContents(with archive: BackupArchive) throws {
        let source = try DatabaseQueue(path: archive.databaseURL.path)
        try source.backup(to: writer)
        try source.close()
    }

    /// Delete all data: an empty database with the current schema.
    public func eraseAll() throws {
        try writer.erase()
        try Self.migrator.migrate(writer)
    }
}
