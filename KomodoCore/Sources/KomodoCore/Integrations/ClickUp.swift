import Foundation

/// ClickUp's API v2 (developer.clickup.com), two-way with one list. ClickUp lists no deletions, so each poll
/// reads the list's open tasks, where a deleted one shows by being missing, and every task changed since the
/// last poll, closed ones included.
public enum ClickUp {
    public static let base = "https://api.clickup.com/api/v2"
    public static let tokenHelpURL = URL(string: "https://app.clickup.com/settings/apps")

    /// `{"err": …, "ECODE": …}`.
    public struct Failure: Decodable, Sendable {
        public var err: String
    }

    public struct UserAnswer: Decodable, Sendable {
        public var user: User

        public struct User: Decodable, Sendable {
            public var id: Number
        }
    }

    /// ClickUp writes IDs, times and estimates as numbers in some places and strings in others.
    public struct Number: Decodable, Equatable, Sendable {
        public var text: String

        public init(_ text: String) { self.text = text }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(Int.self) {
                text = String(value)
            } else {
                text = try container.decode(String.self)
            }
        }

        var int: Int? { Int(text) }
    }

    public struct Teams: Decodable, Sendable {
        public var teams: [Named]
    }

    public struct Spaces: Decodable, Sendable {
        public var spaces: [Named]
    }

    public struct Folders: Decodable, Sendable {
        public var folders: [Folder]
    }

    public struct Folder: Decodable, Sendable {
        public var id: String
        public var name: String
        public var lists: [Named]
    }

    public struct Lists: Decodable, Sendable {
        public var lists: [Named]
    }

    public struct Named: Decodable, Equatable, Sendable {
        public var id: String
        public var name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    public struct List: Decodable, Sendable {
        public var id: String
        public var name: String
        public var statuses: [Status]
    }

    public struct Status: Decodable, Equatable, Sendable {
        public var status: String
        /// `open`, `custom`, `done` or `closed`.
        public var type: String
        public var orderindex: Number?

        public init(status: String, type: String) {
            self.status = status
            self.type = type
        }
    }

    public struct TaskPage: Decodable, Sendable {
        public var tasks: [Task]
        public var lastPage: Bool?

        enum CodingKeys: String, CodingKey {
            case tasks
            case lastPage = "last_page"
        }
    }

    public struct Task: Decodable, Equatable, Sendable {
        public var id: String
        public var name: String
        public var textContent: String?
        public var status: Status
        /// Milliseconds since 1970.
        public var dateUpdated: Number?
        public var startDate: Number?
        public var dueDate: Number?
        /// Whether the date has a time; ClickUp leaves these out of some answers.
        public var startDateTime: Bool?
        public var dueDateTime: Bool?
        /// Milliseconds.
        public var timeEstimate: Number?
        public var assignees: [Assignee]
        public var url: String?
        public var archived: Bool?

        public struct Assignee: Decodable, Equatable, Sendable {
            public var id: Number
        }

        enum CodingKeys: String, CodingKey {
            case id, name, status, assignees, url, archived
            case textContent = "text_content"
            case dateUpdated = "date_updated"
            case startDate = "start_date"
            case dueDate = "due_date"
            case startDateTime = "start_date_time"
            case dueDateTime = "due_date_time"
            case timeEstimate = "time_estimate"
        }

        public init(
            id: String, name: String, textContent: String? = nil, status: Status, dateUpdated: String? = nil,
            startDate: String? = nil, dueDate: String? = nil, timeEstimate: String? = nil, assignees: [String] = []
        ) {
            self.id = id
            self.name = name
            self.textContent = textContent
            self.status = status
            self.dateUpdated = dateUpdated.map(Number.init)
            self.startDate = startDate.map(Number.init)
            self.dueDate = dueDate.map(Number.init)
            self.timeEstimate = timeEstimate.map(Number.init)
            self.assignees = assignees.map { Assignee(id: Number($0)) }
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            textContent = try container.decodeIfPresent(String.self, forKey: .textContent)
            status = try container.decode(Status.self, forKey: .status)
            dateUpdated = try container.decodeIfPresent(Number.self, forKey: .dateUpdated)
            startDate = try container.decodeIfPresent(Number.self, forKey: .startDate)
            dueDate = try container.decodeIfPresent(Number.self, forKey: .dueDate)
            startDateTime = try container.decodeIfPresent(Bool.self, forKey: .startDateTime)
            dueDateTime = try container.decodeIfPresent(Bool.self, forKey: .dueDateTime)
            timeEstimate = try container.decodeIfPresent(Number.self, forKey: .timeEstimate)
            assignees = try container.decodeIfPresent([Assignee].self, forKey: .assignees) ?? []
            url = try container.decodeIfPresent(String.self, forKey: .url)
            archived = try container.decodeIfPresent(Bool.self, forKey: .archived)
        }
    }

    // MARK: Statuses

    public static func kind(ofStatusType type: String) -> ProviderStatus.Kind {
        switch type {
        case "open": .todo
        case "done", "closed": .done
        default: .active
        }
    }

    public static func statuses(_ statuses: [Status]) -> [ProviderStatus] {
        statuses.sorted { ($0.orderindex?.int ?? 0) < ($1.orderindex?.int ?? 0) }.map {
            ProviderStatus(name: $0.status, kind: kind(ofStatusType: $0.type))
        }
    }

    // MARK: Requests

    /// One page of the list's open tasks, or with `since` (milliseconds), every task changed after it.
    public static func tasksQuery(since: String?, page: Int) -> [URLQueryItem] {
        var query = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "include_closed", value: since == nil ? "false" : "true"),
            URLQueryItem(name: "subtasks", value: "false"),
        ]
        if let since { query.append(URLQueryItem(name: "date_updated_gt", value: since)) }
        return query
    }

    /// The open tasks with what changed, a changed task replacing its open copy, and where the next poll starts.
    public static func merge(open: [Task], changed: [Task], cursor: String?) -> (tasks: [Task], cursor: String?) {
        let tasks = open.filter { task in !changed.contains { $0.id == task.id } } + changed
        let latest = (tasks.compactMap { $0.dateUpdated?.int } + [cursor.flatMap { Int($0) }].compactMap { $0 }).max()
        return (tasks, latest.map(String.init))
    }

    /// The task fields for the changed fields, as ClickUp's create and update take them.
    public static func fields(
        of task: TaskItem, _ changes: Set<ExternalItem.Field>, connection: ProviderConnection, calendar: Calendar
    ) -> [String: JSONValue] {
        var body: [String: JSONValue] = [:]
        if changes.contains(.title) { body["name"] = .string(task.title) }
        // ClickUp ignores an empty description, and a single space clears it.
        if changes.contains(.notes) {
            body["description"] = .string(task.notes.flatMap { $0.isEmpty ? nil : $0 } ?? " ")
        }
        let scheduled = connection.dateMapping == .start ? "start_date" : "due_date"
        if !changes.isDisjoint(with: [.date, .minute]) {
            body[scheduled] =
                task.scheduledDate.map {
                    .int(milliseconds(day: $0, minute: task.scheduledMinute ?? 0, calendar: calendar))
                } ?? .null
            body[scheduled + "_time"] = .bool(task.scheduledDate != nil && task.scheduledMinute != nil)
        }
        if connection.dateMapping == .start, changes.contains(.dueDate) {
            body["due_date"] = task.dueDate.map { .int(milliseconds(day: $0, minute: 0, calendar: calendar)) } ?? .null
            body["due_date_time"] = .bool(false)
        }
        if changes.contains(.estimate) {
            body["time_estimate"] = task.estimate.map { .int(Int(($0 / 60).rounded()) * 60_000) } ?? .null
        }
        if !changes.isDisjoint(with: [.done, .column]),
            let status = connection.status(for: task.bucket, isDone: task.isDone)
        {
            body["status"] = .string(status.name)
        }
        return body
    }

    static func milliseconds(day: LocalDate, minute: Int, calendar: Calendar) -> Int {
        Int(day.startOfDay(in: calendar).timeIntervalSince1970 * 1_000) + minute * 60_000
    }
}

extension ExternalItem {
    /// A ClickUp task: the mapped date schedules it, its status places it through the status mapping, and its
    /// estimate is in milliseconds. A date with no time flag counts as timed unless it falls on midnight here.
    public init(_ task: ClickUp.Task, userID: String?, connection: ProviderConnection, calendar: Calendar) {
        func instant(_ number: ClickUp.Number?) -> Date? {
            number?.int.map { Date(timeIntervalSince1970: TimeInterval($0) / 1_000) }
        }
        let start = connection.dateMapping == .start
        var day: LocalDate?
        var minute: Int?
        if let moment = instant(start ? task.startDate : task.dueDate) {
            let schedule = ExternalItem.schedule(at: moment, calendar: calendar)
            day = schedule.day
            let timed = (start ? task.startDateTime : task.dueDateTime) ?? (schedule.minute != 0)
            minute = timed ? schedule.minute : nil
        }
        let status = ProviderStatus(name: task.status.status, kind: ClickUp.kind(ofStatusType: task.status.type))
        let target = connection.target(for: status)
        self.init(
            id: task.id, title: task.name, notes: task.textContent.flatMap { $0.isEmpty ? nil : $0 }, date: day,
            minute: minute,
            dueDate: start ? instant(task.dueDate).map { LocalDate($0, calendar: calendar) } : nil,
            estimate: task.timeEstimate?.int.flatMap { $0 > 0 ? TimeInterval($0) / 1_000 : nil },
            isDone: target == .done, isDeleted: task.archived == true,
            isMine: task.assignees.isEmpty || task.assignees.contains { $0.id.text == userID },
            updatedAt: instant(task.dateUpdated), url: task.url.flatMap(URL.init), bucket: target.bucket)
    }
}
