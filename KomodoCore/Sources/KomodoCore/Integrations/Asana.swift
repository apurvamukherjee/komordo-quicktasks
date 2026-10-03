import Foundation

/// Asana's REST API (developers.asana.com), two-way with one project. Asana lists no deletions, so each poll reads
/// the project's open tasks and those finished since the last poll; a linked task missing from that was deleted.
public enum Asana {
    public static let base = "https://app.asana.com/api/1.0"
    public static let tokenHelpURL = URL(string: "https://app.asana.com/0/my-apps")
    static let taskFields = [
        "name", "notes", "due_on", "due_at", "start_on", "start_at", "completed", "modified_at", "assignee",
        "permalink_url", "num_subtasks",
    ].joined(separator: ",")

    /// Every answer wraps its payload in `data`; a list adds `next_page` while there's more.
    public struct Envelope<Payload: Decodable & Sendable>: Decodable, Sendable {
        public var data: Payload
        public var nextPage: NextPage?

        enum CodingKeys: String, CodingKey {
            case data
            case nextPage = "next_page"
        }
    }

    public struct NextPage: Decodable, Sendable {
        public var offset: String
    }

    /// `{"errors": [{"message": …}]}`.
    public struct Failure: Decodable, Sendable {
        public var errors: [Message]

        public struct Message: Decodable, Sendable {
            public var message: String
        }
    }

    public struct Me: Decodable, Sendable {
        public var gid: String
        public var workspaces: [Named]
    }

    public struct Named: Decodable, Equatable, Sendable {
        public var gid: String
        public var name: String

        public init(gid: String, name: String) {
            self.gid = gid
            self.name = name
        }
    }

    public struct Task: Decodable, Equatable, Sendable {
        public var gid: String
        public var name: String
        public var notes: String?
        /// `2026-10-02`, or `due_at` for a time: `2026-10-02T13:00:00.000Z`.
        public var dueOn: String?
        public var dueAt: String?
        public var startOn: String?
        public var startAt: String?
        public var completed: Bool
        public var modifiedAt: String?
        public var assignee: Assignee?
        public var permalinkURL: String?
        public var numSubtasks: Int?

        public struct Assignee: Decodable, Equatable, Sendable {
            public var gid: String
        }

        enum CodingKeys: String, CodingKey {
            case gid, name, notes, completed, assignee
            case dueOn = "due_on"
            case dueAt = "due_at"
            case startOn = "start_on"
            case startAt = "start_at"
            case modifiedAt = "modified_at"
            case permalinkURL = "permalink_url"
            case numSubtasks = "num_subtasks"
        }

        public init(
            gid: String, name: String, notes: String? = nil, dueOn: String? = nil, dueAt: String? = nil,
            startOn: String? = nil, startAt: String? = nil, completed: Bool = false, modifiedAt: String? = nil,
            assignee: String? = nil, permalinkURL: String? = nil, numSubtasks: Int? = nil
        ) {
            self.gid = gid
            self.name = name
            self.notes = notes
            self.dueOn = dueOn
            self.dueAt = dueAt
            self.startOn = startOn
            self.startAt = startAt
            self.completed = completed
            self.modifiedAt = modifiedAt
            self.assignee = assignee.map(Assignee.init)
            self.permalinkURL = permalinkURL
            self.numSubtasks = numSubtasks
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            gid = try container.decode(String.self, forKey: .gid)
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
            notes = try container.decodeIfPresent(String.self, forKey: .notes)
            dueOn = try container.decodeIfPresent(String.self, forKey: .dueOn)
            dueAt = try container.decodeIfPresent(String.self, forKey: .dueAt)
            startOn = try container.decodeIfPresent(String.self, forKey: .startOn)
            startAt = try container.decodeIfPresent(String.self, forKey: .startAt)
            completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? false
            modifiedAt = try container.decodeIfPresent(String.self, forKey: .modifiedAt)
            assignee = try container.decodeIfPresent(Assignee.self, forKey: .assignee)
            permalinkURL = try container.decodeIfPresent(String.self, forKey: .permalinkURL)
            numSubtasks = try container.decodeIfPresent(Int.self, forKey: .numSubtasks)
        }
    }

    // MARK: Requests

    /// The query for one page of a project's open tasks and those finished since `completedSince`.
    public static func tasksQuery(projectID: String, completedSince: Date?, offset: String?) -> [URLQueryItem] {
        var query = [
            URLQueryItem(name: "project", value: projectID),
            URLQueryItem(
                name: "completed_since", value: completedSince.map { ISO8601DateFormatter().string(from: $0) } ?? "now"),
            URLQueryItem(name: "opt_fields", value: taskFields),
            URLQueryItem(name: "limit", value: "100"),
        ]
        if let offset { query.append(URLQueryItem(name: "offset", value: offset)) }
        return query
    }

    /// The task fields for the changed fields, as Asana's `data` takes them.
    public static func fields(
        of task: TaskItem, _ changes: Set<ExternalItem.Field>, mapping: DateMapping, calendar: Calendar
    ) -> [String: JSONValue] {
        var data: [String: JSONValue] = [:]
        if changes.contains(.title) { data["name"] = .string(task.title) }
        if changes.contains(.notes) { data["notes"] = .string(task.notes ?? "") }
        if changes.contains(.done) { data["completed"] = .bool(task.isDone) }
        let prefix = mapping == .start ? "start" : "due"
        if !changes.isDisjoint(with: [.date, .minute]) {
            if let day = task.scheduledDate, let minute = task.scheduledMinute {
                data[prefix + "_at"] = .string(ExternalItem.instantText(day: day, minute: minute, calendar: calendar))
            } else {
                // Setting the day clears a time, and null clears both.
                data[prefix + "_on"] = task.scheduledDate.map { .string($0.description) } ?? .null
            }
        }
        if mapping == .start {
            if changes.contains(.dueDate) { data["due_on"] = task.dueDate.map { .string($0.description) } ?? .null }
            // Asana refuses a start date without a due date, so the start doubles as the due date.
            if data["start_on"] != nil || data["start_at"] != nil, task.scheduledDate != nil, task.dueDate == nil {
                data["due_on"] = task.scheduledDate.map { .string($0.description) }
            }
        }
        return data
    }

    /// What to send so Asana's subtasks match the task's: an edit for each one matched by ID, or else by title,
    /// and an add for the rest. Subtasks only in Asana stay; Komodo never deletes there for a subtask.
    public static func subtaskChanges(
        local: [Subtask], remote: [Task]
    ) -> [(gid: String?, data: [String: JSONValue])] {
        var unmatched = remote
        var changes: [(gid: String?, data: [String: JSONValue])] = []
        for subtask in local {
            let index =
                unmatched.firstIndex { $0.gid == subtask.id } ?? unmatched.firstIndex { $0.name == subtask.title }
            guard let index else {
                changes.append((nil, ["name": .string(subtask.title), "completed": .bool(subtask.isDone)]))
                continue
            }
            let match = unmatched.remove(at: index)
            var data: [String: JSONValue] = [:]
            if match.name != subtask.title { data["name"] = .string(subtask.title) }
            if match.completed != subtask.isDone { data["completed"] = .bool(subtask.isDone) }
            if !data.isEmpty { changes.append((match.gid, data)) }
        }
        return changes
    }
}

extension ExternalItem {
    /// An Asana task: the mapped date schedules it, with a time when it has one, and with start mapping its due
    /// date is Komodo's due date. Asana has no statuses beyond completion.
    public init(
        _ task: Asana.Task, subtasks: [Asana.Task]?, userID: String?, mapping: DateMapping, calendar: Calendar
    ) {
        let at = mapping == .start ? task.startAt : task.dueAt
        let on = mapping == .start ? task.startOn : task.dueOn
        var day = on.flatMap { LocalDate(iso: String($0.prefix(10))) }
        var minute: Int?
        if let instant = at.flatMap(ExternalItem.instant) {
            (day, minute) = ExternalItem.schedule(at: instant, calendar: calendar)
        }
        self.init(
            id: task.gid, title: task.name, notes: task.notes.flatMap { $0.isEmpty ? nil : $0 }, date: day,
            minute: minute,
            dueDate: mapping == .start ? task.dueOn.flatMap { LocalDate(iso: String($0.prefix(10))) } : nil,
            isDone: task.completed, isMine: task.assignee == nil || task.assignee?.gid == userID,
            updatedAt: task.modifiedAt.flatMap(ExternalItem.instant), url: task.permalinkURL.flatMap(URL.init),
            subtasks: subtasks?.map { Subtask(id: $0.gid, title: $0.name, isDone: $0.completed) })
    }
}
