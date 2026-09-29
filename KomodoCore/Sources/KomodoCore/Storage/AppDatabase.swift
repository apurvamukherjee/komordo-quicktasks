import Foundation
import GRDB

/// Everything the board loads at launch.
public struct StoredBoard: Sendable {
    public var lists: [TaskList]
    public var tasks: [TaskItem]
    /// In Trash, and archived: kept apart so nothing on the Board has to skip them.
    public var trash: [TaskItem]
    public var archived: [TaskItem]
    public var preferences: [String: String]
}

/// Komodo's SQLite file (ARCHITECTURE §5): lists, tasks with their subtasks and work sessions, and preferences.
/// The store writes each change through as it happens and reads everything back at launch.
public final class AppDatabase: Sendable {
    private let writer: any DatabaseWriter

    public init(_ writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.migrator.migrate(writer)
    }

    /// The database in Application Support, created with its folder on first launch.
    public static func open(at url: URL) throws -> AppDatabase {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return try AppDatabase(DatabasePool(path: url.path))
    }

    /// For tests and previews: nothing touches the disk.
    public static func inMemory() throws -> AppDatabase { try AppDatabase(DatabaseQueue()) }

    // MARK: Schema

    /// v1 mirrors the in-memory models. It departs from ARCHITECTURE §5 where the models do: a repeat rule is a
    /// JSON column on its parent rather than a `recurrences` table, ranks are REAL, estimates are seconds, and
    /// instants are seconds since 1970.
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.execute(
                sql: """
                    CREATE TABLE lists (
                      id TEXT PRIMARY KEY, name TEXT NOT NULL, color TEXT NOT NULL, letter TEXT NOT NULL,
                      position INTEGER NOT NULL, updated_at REAL NOT NULL
                    );
                    CREATE TABLE tasks (
                      id TEXT PRIMARY KEY,
                      list_id TEXT NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
                      title TEXT NOT NULL,
                      bucket TEXT NOT NULL CHECK (bucket IN ('backlog','week','today')),
                      rank REAL NOT NULL,
                      estimate REAL,
                      notes TEXT, notes_rtf BLOB,
                      opens_links INTEGER NOT NULL DEFAULT 1,
                      scheduled_date TEXT, scheduled_minute INTEGER, due_date TEXT,
                      repeat_rule TEXT, repeat_start TEXT, repeat_parent_id TEXT,
                      reminds_at_start INTEGER NOT NULL DEFAULT 1,
                      completed_at REAL,
                      source TEXT, source_title TEXT, source_url TEXT,
                      created_at REAL, edited_at REAL, updated_at REAL NOT NULL
                    );
                    CREATE INDEX tasks_list ON tasks(list_id);
                    CREATE TABLE subtasks (
                      id TEXT PRIMARY KEY,
                      task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
                      title TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0, position INTEGER NOT NULL
                    );
                    CREATE INDEX subtasks_task ON subtasks(task_id);
                    CREATE TABLE sessions (
                      id INTEGER PRIMARY KEY AUTOINCREMENT,
                      task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
                      started_at REAL NOT NULL, ended_at REAL
                    );
                    CREATE INDEX sessions_task ON sessions(task_id);
                    CREATE TABLE preferences (key TEXT PRIMARY KEY, value TEXT NOT NULL, updated_at REAL NOT NULL);
                    """)
        }
        migrator.registerMigration("v2 trash and archive") { db in
            try db.execute(
                sql: "ALTER TABLE tasks ADD COLUMN deleted_at REAL; ALTER TABLE tasks ADD COLUMN archived_at REAL")
        }
        return migrator
    }

    // MARK: Reading

    public func load() throws -> StoredBoard {
        try writer.read { db in
            let lists = try Row.fetchAll(db, sql: "SELECT * FROM lists ORDER BY position").map(Self.list)
            var subtasks: [String: [Subtask]] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT * FROM subtasks ORDER BY position") {
                subtasks[row["task_id"], default: []].append(
                    Subtask(id: row["id"], title: row["title"], isDone: row["done"]))
            }
            var sessions: [String: [WorkSession]] = [:]
            for row in try Row.fetchAll(db, sql: "SELECT * FROM sessions ORDER BY started_at") {
                sessions[row["task_id"], default: []].append(
                    WorkSession(start: Self.date(row["started_at"]), end: (row["ended_at"] as Double?).map(Self.date)))
            }
            let tasks = try Row.fetchAll(db, sql: "SELECT * FROM tasks").map { row in
                let id: String = row["id"]
                return try Self.task(row, subtasks: subtasks[id] ?? [], sessions: sessions[id] ?? [])
            }
            let preferences = try Row.fetchAll(db, sql: "SELECT key, value FROM preferences").reduce(
                into: [String: String]()
            ) { $0[$1["key"]] = $1["value"] }
            return StoredBoard(
                lists: lists, tasks: tasks.filter { $0.deletedAt == nil && $0.archivedAt == nil },
                trash: tasks.filter { $0.deletedAt != nil },
                archived: tasks.filter { $0.deletedAt == nil && $0.archivedAt != nil }, preferences: preferences)
        }
    }

    // MARK: Writing

    /// Writes one change in a single transaction: lists first, since tasks point at them.
    public func apply(_ change: BoardChange, at now: Date = Date()) throws {
        guard !change.isEmpty else { return }
        try writer.write { db in
            for (position, list) in change.savedLists.enumerated() {
                try db.execute(
                    sql: """
                        INSERT INTO lists (id, name, color, letter, position, updated_at) VALUES (?, ?, ?, ?, ?, ?)
                        ON CONFLICT(id) DO UPDATE SET name = excluded.name, color = excluded.color,
                          letter = excluded.letter, position = excluded.position, updated_at = excluded.updated_at
                        """,
                    arguments: [list.id, list.name, list.color, list.letter, position, now.timeIntervalSince1970])
            }
            for id in change.deletedListIDs { try db.execute(sql: "DELETE FROM lists WHERE id = ?", arguments: [id]) }
            for id in change.deletedTaskIDs { try db.execute(sql: "DELETE FROM tasks WHERE id = ?", arguments: [id]) }
            for task in change.savedTasks { try Self.save(task, in: db, at: now) }
        }
    }

    public func setPreference(_ value: String, for key: String, at now: Date = Date()) throws {
        try writer.write { db in
            try db.execute(
                sql: """
                    INSERT INTO preferences (key, value, updated_at) VALUES (?, ?, ?)
                    ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at
                    """,
                arguments: [key, value, now.timeIntervalSince1970])
        }
    }

    /// Upserts the task row (never REPLACE, which would cascade away its children), then rewrites its subtasks
    /// and sessions, which are small.
    private static func save(_ task: TaskItem, in db: Database, at now: Date) throws {
        let columns: [(String, (any DatabaseValueConvertible)?)] = [
            ("id", task.id), ("list_id", task.listID), ("title", task.title), ("bucket", task.bucket.rawValue),
            ("rank", task.rank), ("estimate", task.estimate), ("notes", task.notes), ("notes_rtf", task.notesRTF),
            ("opens_links", task.opensLinks), ("scheduled_date", task.scheduledDate?.description),
            ("scheduled_minute", task.scheduledMinute), ("due_date", task.dueDate?.description),
            ("repeat_rule", try task.repeatRule.map(RepeatRuleColumn.encode)),
            ("repeat_start", task.repeatStart?.description), ("repeat_parent_id", task.repeatParentID),
            ("reminds_at_start", task.remindsAtStart), ("completed_at", task.completedAt?.timeIntervalSince1970),
            ("deleted_at", task.deletedAt?.timeIntervalSince1970),
            ("archived_at", task.archivedAt?.timeIntervalSince1970),
            ("source", task.source?.rawValue), ("source_title", task.sourceTitle),
            ("source_url", task.sourceURL?.absoluteString), ("created_at", task.createdAt?.timeIntervalSince1970),
            ("edited_at", task.editedAt?.timeIntervalSince1970), ("updated_at", now.timeIntervalSince1970),
        ]
        let names = columns.map(\.0)
        let updates = names.dropFirst().map { "\($0) = excluded.\($0)" }.joined(separator: ", ")
        try db.execute(
            sql: """
                INSERT INTO tasks (\(names.joined(separator: ", ")))
                VALUES (\(Array(repeating: "?", count: names.count).joined(separator: ", ")))
                ON CONFLICT(id) DO UPDATE SET \(updates)
                """,
            arguments: StatementArguments(columns.map(\.1)))
        try db.execute(sql: "DELETE FROM subtasks WHERE task_id = ?", arguments: [task.id])
        for (position, subtask) in task.subtasks.enumerated() {
            try db.execute(
                sql: "INSERT INTO subtasks (id, task_id, title, done, position) VALUES (?, ?, ?, ?, ?)",
                arguments: [subtask.id, task.id, subtask.title, subtask.isDone, position])
        }
        try db.execute(sql: "DELETE FROM sessions WHERE task_id = ?", arguments: [task.id])
        for session in task.sessions {
            try db.execute(
                sql: "INSERT INTO sessions (task_id, started_at, ended_at) VALUES (?, ?, ?)",
                arguments: [task.id, session.start.timeIntervalSince1970, session.end?.timeIntervalSince1970])
        }
    }

    // MARK: Rows

    private static func date(_ seconds: Double) -> Date { Date(timeIntervalSince1970: seconds) }

    private static func list(_ row: Row) -> TaskList {
        TaskList(id: row["id"], name: row["name"], color: row["color"], letter: row["letter"])
    }

    private static func task(_ row: Row, subtasks: [Subtask], sessions: [WorkSession]) throws -> TaskItem {
        let bucketName: String = row["bucket"]
        guard let bucket = Bucket(rawValue: bucketName) else {
            throw StorageError.unreadable(column: "bucket", value: bucketName)
        }
        return TaskItem(
            id: row["id"], listID: row["list_id"], title: row["title"], bucket: bucket, rank: row["rank"],
            estimate: row["estimate"], notes: row["notes"], notesRTF: row["notes_rtf"], opensLinks: row["opens_links"],
            scheduledDate: (row["scheduled_date"] as String?).flatMap(LocalDate.init(iso:)),
            scheduledMinute: row["scheduled_minute"],
            dueDate: (row["due_date"] as String?).flatMap(LocalDate.init(iso:)),
            repeatRule: try (row["repeat_rule"] as String?).map(RepeatRuleColumn.decode),
            repeatStart: (row["repeat_start"] as String?).flatMap(LocalDate.init(iso:)),
            repeatParentID: row["repeat_parent_id"], remindsAtStart: row["reminds_at_start"],
            completedAt: (row["completed_at"] as Double?).map(date),
            deletedAt: (row["deleted_at"] as Double?).map(date), archivedAt: (row["archived_at"] as Double?).map(date),
            subtasks: subtasks,
            source: (row["source"] as String?).flatMap(TaskSource.init(rawValue:)), sourceTitle: row["source_title"],
            sourceURL: (row["source_url"] as String?).flatMap(URL.init(string:)), sessions: sessions,
            createdAt: (row["created_at"] as Double?).map(date), editedAt: (row["edited_at"] as Double?).map(date))
    }
}

public enum StorageError: Error, Equatable {
    /// A stored value the app can't read back, such as a bucket it doesn't know.
    case unreadable(column: String, value: String)
}

/// A repeat rule as a small JSON object in its parent's row.
private enum RepeatRuleColumn {
    private struct Stored: Codable {
        var interval: Int
        var unit: String
        var weekdays: [Int]
        var endsOn: String?
    }

    static func encode(_ rule: RepeatRule) throws -> String {
        let stored = Stored(
            interval: rule.interval, unit: rule.unit.rawValue, weekdays: rule.weekdays.sorted(),
            endsOn: rule.endsOn?.description)
        return String(decoding: try JSONEncoder().encode(stored), as: UTF8.self)
    }

    static func decode(_ text: String) throws -> RepeatRule {
        let stored = try JSONDecoder().decode(Stored.self, from: Data(text.utf8))
        guard let unit = RepeatRule.Unit(rawValue: stored.unit) else {
            throw StorageError.unreadable(column: "repeat_rule", value: text)
        }
        return RepeatRule(
            interval: stored.interval, unit: unit, weekdays: Set(stored.weekdays),
            endsOn: stored.endsOn.flatMap(LocalDate.init(iso:)))
    }
}
