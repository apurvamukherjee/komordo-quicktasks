import Foundation
import Testing

@testable import KomodoCore

struct BackupTests {
    private let work = TaskList(id: "work", name: "Work", color: "lime")
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private var task: TaskItem {
        TaskItem(
            id: "spec", listID: "work", title: "Write spec, v2", bucket: .today, rank: 1, estimate: 2_700,
            notes: "Ask Apurva \"soon\"", notesRTF: Data([1, 2, 3]), opensLinks: true, remindsAtStart: true,
            subtasks: [Subtask(id: "a", title: "Outline", isDone: true)],
            sessions: [WorkSession(start: start, end: start.addingTimeInterval(1_200))])
    }

    private func scratch() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "komodo-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func csvQuotesOnlyWhatNeedsIt() {
        #expect(CSV.field("plain") == "plain")
        #expect(CSV.field("a, b") == "\"a, b\"")
        #expect(CSV.field("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(CSV.field("two\nlines") == "\"two\nlines\"")
        #expect(CSV.line(["id", "a,b"]) == "id,\"a,b\"\r\n")
    }

    @Test func fileNamesSortByDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .gmt
        #expect(Backup.fileName(on: start, calendar: calendar) == "komodo-backup-2026-09-21.zip")
        #expect(
            Backup.fileName(on: start, calendar: calendar, suffix: "before-restore")
                == "komodo-backup-2026-09-21-before-restore.zip")
        #expect(Backup.fileName(on: start, calendar: calendar, isProtected: true) == "komodo-backup-2026-09-21.kbak")
    }

    @Test func onlyKomodosOwnFilesPass() {
        let files = ["manifest.json", "komodo.sqlite", "data.json", "tasks.csv", "sessions.csv"]
        #expect(Backup.backupRoot(["b/"] + files.map { "b/" + $0 }) == "b")
        #expect(Backup.backupRoot(files) == "")
        #expect(Backup.backupRoot(["b/manifest.json", "b/komodo.sqlite", "b/../evil"]) == nil)
        #expect(Backup.backupRoot(["b/manifest.json", "b/komodo.sqlite", "b/notes.txt"]) == nil)
        #expect(Backup.backupRoot(["b/manifest.json", "c/komodo.sqlite"]) == nil)
        #expect(Backup.backupRoot(["b/manifest.json"]) == nil)
        #expect(Backup.backupRoot(["a/b/manifest.json", "a/b/komodo.sqlite"]) == nil)
    }

    /// FEATURES §4.21's acceptance: export, delete all data, restore gives back the same lists, tasks, sessions
    /// and settings.
    @Test func exportDeleteRestoreRoundTrips() throws {
        let folder = try scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        let database = try AppDatabase.open(at: folder.appending(path: "Komodo.sqlite"))
        var change = BoardChange.lists(from: [], to: [work])
        change.savedTasks = [task]
        try database.apply(change)
        try database.setPreference("0", for: "showsGIF")
        let before = try database.load()

        let zip = folder.appending(path: "komodo-backup-2026-09-21.zip")
        try Backup.export(database, appVersion: "1.0.0", to: zip, at: start)
        try database.eraseAll()
        #expect(try database.load().tasks.isEmpty)

        let archive = try Backup.open(zip)
        #expect(archive.manifest.counts == .init(lists: 1, tasks: 1, sessions: 1))
        #expect(archive.manifest.appVersion == "1.0.0")
        try database.replaceContents(with: archive)
        try archive.discard()
        let after = try database.load()
        #expect(after.lists == before.lists)
        #expect(after.tasks == before.tasks)
        #expect(after.preferences == before.preferences)
    }

    @Test func aProtectedBackupNeedsItsPassword() throws {
        let folder = try scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        let database = try AppDatabase.open(at: folder.appending(path: "Komodo.sqlite"))
        var change = BoardChange.lists(from: [], to: [work])
        change.savedTasks = [task]
        try database.apply(change)

        // Renamed to .zip, so the password is asked for because of what the file is, not what it's called.
        let sealed = folder.appending(path: "komodo-backup-2026-09-21.zip")
        try Backup.export(database, appVersion: "1.0.0", to: sealed, password: "Apurva's pw", at: start)
        #expect(BackupCrypto.isSealed(try Data(contentsOf: sealed)))
        #expect(throws: BackupError.passwordRequired) { try Backup.open(sealed) }
        #expect(throws: BackupError.wrongPassword) { try Backup.open(sealed, password: "nope") }

        let archive = try Backup.open(sealed, password: "Apurva's pw")
        defer { try? archive.discard() }
        #expect(archive.fileName == "komodo-backup-2026-09-21.zip")
        #expect(archive.manifest.counts == .init(lists: 1, tasks: 1, sessions: 1))
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: NSTemporaryDirectory())
        #expect(!leftovers.contains { $0.hasPrefix("komodo-unsealed-") })
    }

    @Test func theZipHoldsReadableCopies() throws {
        let folder = try scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        let database = try AppDatabase.open(at: folder.appending(path: "Komodo.sqlite"))
        var change = BoardChange.lists(from: [], to: [work])
        change.savedTasks = [task]
        try database.apply(change)
        let zip = folder.appending(path: "out.zip")
        try Backup.export(database, appVersion: "1.0.0", to: zip, at: start)

        let archive = try Backup.open(zip)
        defer { try? archive.discard() }
        let contents = archive.databaseURL.deletingLastPathComponent()
        let tasks = try String(contentsOf: contents.appending(path: "tasks.csv"), encoding: .utf8)
        #expect(tasks.contains("\"Write spec, v2\""))
        #expect(tasks.contains("45.0,20.0"))
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: contents.appending(path: "data.json")))
        let tables = try #require(json as? [String: [[String: Any]]])
        #expect(tables["tasks"]?.first?["title"] as? String == "Write spec, v2")
        #expect(tables["tasks"]?.first?["notes_rtf"] == nil)
    }

    @Test func aRestoreRefusesWhatItCantTrust() throws {
        let folder = try scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        let text = folder.appending(path: "notes.txt")
        try Data("hello".utf8).write(to: text)
        #expect(throws: BackupError.notABackup) { try Backup.open(text) }

        let database = try AppDatabase.open(at: folder.appending(path: "Komodo.sqlite"))
        let zip = folder.appending(path: "newer.zip")
        try Backup.export(database, appVersion: "9.0.0", to: zip, at: start)
        let unzipped = folder.appending(path: "unzipped")
        try run("/usr/bin/ditto", "-x", "-k", zip.path, unzipped.path)
        let manifestURL = unzipped.appending(path: "newer/manifest.json")
        let manifest = try String(contentsOf: manifestURL, encoding: .utf8)
            .replacingOccurrences(
                of: "\"schemaVersion\" : \(AppDatabase.schemaVersion)", with: "\"schemaVersion\" : 99")
        try Data(manifest.utf8).write(to: manifestURL)
        try FileManager.default.removeItem(at: zip)
        try run("/usr/bin/ditto", "-c", "-k", "--keepParent", unzipped.appending(path: "newer").path, zip.path)
        #expect(throws: BackupError.newerVersion) { try Backup.open(zip) }

        try Data("not sqlite".utf8).write(to: unzipped.appending(path: "newer/komodo.sqlite"))
        try Data(manifest.replacingOccurrences(of: "99", with: "1").utf8).write(to: manifestURL)
        try FileManager.default.removeItem(at: zip)
        try run("/usr/bin/ditto", "-c", "-k", "--keepParent", unzipped.appending(path: "newer").path, zip.path)
        #expect(throws: BackupError.damaged) { try Backup.open(zip) }
    }

    @Test func pruningKeepsTheNewest() throws {
        let folder = try scratch()
        defer { try? FileManager.default.removeItem(at: folder) }
        let names =
            (20...24).map { "komodo-backup-2026-09-\($0).zip" } + ["komodo-backup-2026-09-25.kbak", "holiday.zip"]
        for name in names { try Data().write(to: folder.appending(path: name)) }
        let removed = try Backup.prune(folder, keeping: 3).map(\.lastPathComponent).sorted()
        #expect(removed == (20...22).map { "komodo-backup-2026-09-\($0).zip" })
        let left = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(
            left == ["holiday.zip"] + (23...24).map { "komodo-backup-2026-09-\($0).zip" } + [
                "komodo-backup-2026-09-25.kbak"
            ])
    }

    private func run(_ tool: String, _ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(filePath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
    }
}
