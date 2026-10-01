import Foundation

/// The tools `komodo-mcp` offers (FEATURES §5.1), read and written straight against Komodo's database. The
/// running app hears about each write and refreshes; `start_focus` goes through the app, which owns the timer.
public struct KomodoTools: Sendable {
    public struct Outcome: Sendable {
        public var text: String
        public var isError = false
        public var changedBoard = false
        public var opens: URL?
    }

    /// A tool refused its arguments; the message goes back to the AI app as the tool's error text.
    struct Refusal: Error {
        var message: String
        init(_ message: String) { self.message = message }
    }

    let database: AppDatabase
    let now: @Sendable () -> Date
    let calendar: Calendar

    public init(database: AppDatabase, calendar: Calendar = .current, now: @escaping @Sendable () -> Date = Date.init) {
        self.database = database
        self.calendar = calendar
        self.now = now
    }

    public func call(_ name: String, arguments: JSONValue) -> Outcome {
        do {
            let board = try database.load()
            guard AppSettings(stored: board.preferences).allowsMCP else {
                throw Refusal("Komodo's MCP server is off. Turn it on in Komodo ▸ Settings ▸ Local MCP server.")
            }
            let session = Session(board: board, arguments: arguments, now: now(), calendar: calendar)
            switch name {
            case "list_lists": return Outcome(text: Self.json(session.lists))
            case "list_tasks": return Outcome(text: Self.json(try session.listTasks()))
            case "create_task": return try write(session.createTask())
            case "update_task": return try write(session.updateTask())
            case "complete_task": return try write(session.completeTask())
            case "complete_subtask": return try write(session.completeSubtask())
            case "log_time": return try write(session.logTime())
            case "start_focus":
                let task = try session.openTask(session.required("task_id"))
                var outcome = Outcome(text: "Starting “\(task.title)” in Komodo.")
                var url = URLComponents()
                url.scheme = "komodo"
                url.host = "start"
                url.queryItems = [URLQueryItem(name: "task", value: task.id)]
                outcome.opens = url.url
                return outcome
            default: throw Refusal("Unknown tool: \(name)")
            }
        } catch let refusal as Refusal {
            return Outcome(text: refusal.message, isError: true)
        } catch {
            return Outcome(text: "Komodo couldn't read or save its data: \(error)", isError: true)
        }
    }

    private func write(_ task: TaskItem) throws -> Outcome {
        var change = BoardChange()
        change.savedTasks = [task]
        try database.apply(change, at: now())
        let session = Session(board: try database.load(), arguments: [:], now: now(), calendar: calendar)
        return Outcome(text: Self.json(session.describe(task)), changedBoard: true)
    }

    static func json(_ value: JSONValue) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(value)).map { String(decoding: $0, as: UTF8.self) } ?? "null"
    }
}

/// One call's view of the board, with its arguments.
private struct Session {
    let board: StoredBoard
    let arguments: JSONValue
    let now: Date
    let calendar: Calendar

    private var activeLists: [TaskList] { board.lists.filter(\.isActive) }

    private var week: WeekRange {
        WeekRange(
            containing: LocalDate(now, calendar: calendar),
            firstWeekday: AppSettings(stored: board.preferences).weekStart.firstWeekday, calendar: calendar)
    }

    var lists: JSONValue {
        .array(
            activeLists.map {
                [
                    "id": .string($0.id), "name": .string($0.name), "color": .string($0.color),
                    "badge": .string($0.letter),
                ]
            })
    }

    // MARK: Reading

    func listTasks() throws -> JSONValue {
        let listID = arguments["list_id"]?.string
        if let listID { _ = try list(listID) }
        let column = try arguments["column"]?.string.map(bucket)
        let date = try arguments["date"]?.string.map(day)
        let status = arguments["status"]?.string ?? "open"
        guard ["open", "done", "all"].contains(status) else {
            throw KomodoTools.Refusal("status is open, done or all.")
        }
        let tasks = board.tasks
            .filter { listID == nil || $0.listID == listID }
            .filter { column == nil || $0.column(in: week) == column }
            .filter { date == nil || $0.scheduledDate == date }
            .filter { status == "all" || $0.isDone == (status == "done") }
            .sorted { ($0.column(in: week).order, $0.rank) < ($1.column(in: week).order, $1.rank) }
        return .array(tasks.map(describe))
    }

    func describe(_ task: TaskItem) -> JSONValue {
        var object: [String: JSONValue] = [
            "id": .string(task.id), "list_id": .string(task.listID), "title": .string(task.title),
            "column": .string(task.column(in: week).rawValue), "done": .bool(task.isDone),
            "time_taken_minutes": .int(Int((task.timeTaken(at: now) / 60).rounded())),
        ]
        if let estimate = task.estimate { object["estimate_minutes"] = .int(Int((estimate / 60).rounded())) }
        if let date = task.scheduledDate { object["date"] = .string(date.description) }
        if let minute = task.scheduledMinute {
            object["time"] = .string(String(format: "%02d:%02d", minute / 60, minute % 60))
        }
        if let notes = task.notes, !notes.isEmpty { object["notes"] = .string(notes) }
        if !task.subtasks.isEmpty {
            object["subtasks"] = .array(
                task.subtasks.map { ["id": .string($0.id), "title": .string($0.title), "done": .bool($0.isDone)] })
        }
        return .object(object)
    }

    // MARK: Writing

    func createTask() throws -> TaskItem {
        let parsed = EstimateParser.parse(try required("title"))
        guard !parsed.title.isEmpty else { throw KomodoTools.Refusal("title can't be empty.") }
        guard let listID = try arguments["list_id"]?.string.map({ try list($0).id }) ?? activeLists.first?.id else {
            throw KomodoTools.Refusal("Komodo has no list yet. Open Komodo once to make one.")
        }
        // Like an imported task (FEATURES §5): no column and no date means Backlog.
        var task = TaskItem(
            id: UUID().uuidString, listID: listID, title: parsed.title,
            bucket: try arguments["column"]?.string.map(bucket) ?? .backlog, rank: 0, estimate: parsed.estimate,
            createdAt: now)
        try applyFields(to: &task)
        task.subtasks = (arguments["subtasks"]?.array ?? []).compactMap(\.string).map {
            Subtask(id: UUID().uuidString, title: $0)
        }
        task.rank = endRank(of: task.column(in: week))
        return task
    }

    func updateTask() throws -> TaskItem {
        var task = try openTask(try required("id"))
        if let title = arguments["title"]?.string {
            let parsed = EstimateParser.parse(title)
            guard !parsed.title.isEmpty else { throw KomodoTools.Refusal("title can't be empty.") }
            task.title = parsed.title
            if let estimate = parsed.estimate { task.estimate = estimate }
        }
        if let listID = arguments["list_id"]?.string { task.listID = try list(listID).id }
        let column = task.column(in: week)
        try applyFields(to: &task)
        if let target = try arguments["column"]?.string.map(bucket), target != task.column(in: week) {
            // Moving a dated task to another column drops the date, as dragging it there does.
            task.bucket = target
            task.scheduledDate = nil
            task.scheduledMinute = nil
        }
        if task.column(in: week) != column { task.rank = endRank(of: task.column(in: week)) }
        task.editedAt = now
        return task
    }

    func completeTask() throws -> TaskItem {
        var task = try openTask(try required("id"))
        task.completedAt = now
        for index in task.sessions.indices where task.sessions[index].end == nil { task.sessions[index].end = now }
        return task
    }

    func completeSubtask() throws -> TaskItem {
        var task = try openTask(try required("task_id"))
        let id = try required("subtask_id")
        guard let index = task.subtasks.firstIndex(where: { $0.id == id }) else {
            throw KomodoTools.Refusal("No subtask \(id) on that task. list_tasks shows subtask IDs.")
        }
        task.subtasks[index].isDone = true
        return task
    }

    func logTime() throws -> TaskItem {
        guard let id = arguments["task_id"]?.string, var task = board.tasks.first(where: { $0.id == id }) else {
            throw KomodoTools.Refusal("task_id doesn't match a task. list_tasks shows task IDs.")
        }
        guard let minutes = arguments["minutes"]?.number, minutes > 0, minutes <= 24 * 60 else {
            throw KomodoTools.Refusal("minutes is a number from 1 to 1440.")
        }
        let end: Date
        if let text = arguments["ended_at"]?.string {
            guard let date = ISO8601DateFormatter().date(from: text) else {
                throw KomodoTools.Refusal("ended_at is an ISO 8601 time, such as 2026-10-02T17:30:00+05:30.")
            }
            end = date
        } else {
            end = now
        }
        task.sessions.append(WorkSession(start: end.addingTimeInterval(-minutes * 60), end: end))
        task.sessions.sort { $0.start < $1.start }
        return task
    }

    /// Notes, estimate, date and time, shared by create and update.
    private func applyFields(to task: inout TaskItem) throws {
        if let notes = arguments["notes"]?.string {
            task.notes = notes.isEmpty ? nil : notes
            // The plain text is now the truth; the editor rebuilds its formatting from it.
            task.notesRTF = nil
        }
        if let minutes = arguments["estimate_minutes"]?.number {
            guard minutes >= 0 else { throw KomodoTools.Refusal("estimate_minutes can't be negative.") }
            task.estimate = minutes == 0 ? nil : minutes * 60
        }
        if let text = arguments["date"]?.string {
            task.scheduledDate = text.isEmpty ? nil : try day(text)
            if text.isEmpty { task.scheduledMinute = nil }
        }
        if let text = arguments["time"]?.string {
            if text.isEmpty {
                task.scheduledMinute = nil
            } else {
                let parts = text.split(separator: ":").compactMap { Int($0) }
                guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else {
                    throw KomodoTools.Refusal("time is HH:MM in 24-hour time, such as 14:30.")
                }
                guard task.scheduledDate != nil else { throw KomodoTools.Refusal("A time needs a date too.") }
                task.scheduledMinute = parts[0] * 60 + parts[1]
            }
        }
    }

    // MARK: Lookups

    func required(_ key: String) throws -> String {
        guard let value = arguments[key]?.string, !value.isEmpty else {
            throw KomodoTools.Refusal("\(key) is required.")
        }
        return value
    }

    /// A task on the Board: not in Trash, archived, or in a list that is.
    func openTask(_ id: String) throws -> TaskItem {
        guard let task = board.tasks.first(where: { $0.id == id }) else {
            throw KomodoTools.Refusal("No task \(id) on the Board. list_tasks shows task IDs.")
        }
        return task
    }

    private func list(_ id: String) throws -> TaskList {
        guard let list = activeLists.first(where: { $0.id == id }) else {
            throw KomodoTools.Refusal("No list \(id). list_lists shows list IDs.")
        }
        return list
    }

    private func bucket(_ name: String) throws -> Bucket {
        guard let bucket = Bucket(rawValue: name) else {
            throw KomodoTools.Refusal("column is backlog, week or today.")
        }
        return bucket
    }

    private func day(_ text: String) throws -> LocalDate {
        guard let date = LocalDate(iso: text) else { throw KomodoTools.Refusal("date is YYYY-MM-DD.") }
        return date
    }

    private func endRank(of column: Bucket) -> Double {
        (board.tasks.filter { $0.column(in: week) == column && !$0.isDone }.map(\.rank).max() ?? 0) + 1
    }
}

extension Bucket {
    fileprivate var order: Int {
        switch self {
        case .today: 0
        case .week: 1
        case .backlog: 2
        }
    }
}
