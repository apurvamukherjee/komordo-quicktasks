import Foundation

/// Notion's API (developers.notion.com, version 2026-03-11), two-way with one database's data source. Pages are
/// read whole each poll, since a query can't list deletions; a database holds one list's worth, a page or two.
/// A page's properties are read through its data source's schema: the title, the first date, the status, the
/// first people property for "Only my items", and every checkbox as a subtask (FEATURES §5).
public enum Notion {
    public static let base = "https://api.notion.com/v1"
    public static let version = "2026-03-11"
    public static let tokenHelpURL = URL(string: "https://www.notion.so/profile/integrations")

    /// `{"object": "error", "status": 404, "code": "object_not_found", "message": …}`.
    public struct Failure: Decodable, Sendable {
        public var code: String
        public var message: String
    }

    public struct List<Item: Decodable & Sendable>: Decodable, Sendable {
        public var results: [Item]
        public var hasMore: Bool
        public var nextCursor: String?

        enum CodingKeys: String, CodingKey {
            case results
            case hasMore = "has_more"
            case nextCursor = "next_cursor"
        }
    }

    public struct DataSource: Decodable, Sendable {
        public var id: String
        public var title: [RichText]?
        public var properties: [String: JSONValue]

        public init(id: String, title: String, properties: [String: JSONValue]) {
            self.id = id
            self.title = [RichText(plainText: title)]
            self.properties = properties
        }

        public var name: String {
            let text = (title ?? []).map(\.plainText).joined()
            return text.isEmpty ? "Untitled" : text
        }
    }

    public struct RichText: Decodable, Sendable {
        public var plainText: String

        enum CodingKeys: String, CodingKey {
            case plainText = "plain_text"
        }
    }

    public struct Page: Decodable, Sendable {
        public var id: String
        public var url: String?
        public var lastEditedTime: String?
        public var inTrash: Bool?
        public var properties: [String: JSONValue]

        enum CodingKeys: String, CodingKey {
            case id, url, properties
            case lastEditedTime = "last_edited_time"
            case inTrash = "in_trash"
        }

        public init(id: String, url: String? = nil, lastEditedTime: String? = nil, properties: [String: JSONValue]) {
            self.id = id
            self.url = url
            self.lastEditedTime = lastEditedTime
            self.properties = properties
        }
    }

    /// The bot behind the token, and the person who made it when Notion says.
    public struct Me: Decodable, Sendable {
        public var bot: Bot?

        public struct Bot: Decodable, Sendable {
            public var owner: Owner?
        }

        public struct Owner: Decodable, Sendable {
            public var user: Person?
        }

        public struct Person: Decodable, Sendable {
            public var id: String
        }

        public var ownerID: String? { bot?.owner?.user?.id }
    }

    /// Which properties hold what, read from a data source's schema.
    public struct Schema: Equatable, Sendable {
        public var title: String
        public var date: String?
        public var status: String?
        /// `status` or `select`.
        public var statusType: String
        public var statuses: [ProviderStatus]
        public var people: String?
        public var checkboxes: [String]

        public init(_ properties: [String: JSONValue]) {
            // Sorted by name, so "the first date" is the same one every time.
            let named = properties.sorted { $0.key < $1.key }
            func first(_ type: String) -> String? { named.first { $0.value["type"]?.string == type }?.key }
            title = first("title") ?? "Name"
            date = first("date")
            let status = first("status")
            let select = named.first { $0.key.lowercased() == "status" && $0.value["type"]?.string == "select" }?.key
            self.status = status ?? select
            statusType = status == nil ? "select" : "status"
            people = first("people")
            checkboxes = named.filter { $0.value["type"]?.string == "checkbox" }.map(\.key)
            statuses = []
            if let name = self.status, let property = properties[name] {
                statuses = Self.statuses(property, type: statusType)
            }
        }

        /// A status property's options, kinds taken from its groups: the first is not started and the last is
        /// finished, as Notion names them To-do, In progress and Complete. A select's options are all to do.
        static func statuses(_ property: JSONValue, type: String) -> [ProviderStatus] {
            let options = property[type]?["options"]?.array ?? []
            let groups = property[type]?["groups"]?.array ?? []
            return options.compactMap { option in
                guard let name = option["name"]?.string else { return nil }
                let id = option["id"]?.string
                let group = groups.firstIndex { ($0["option_ids"]?.array ?? []).contains { $0.string == id } }
                guard let group else { return ProviderStatus(name: name, kind: .todo) }
                // By name first, then by place, in case the groups were renamed.
                let groupName = groups[group]["name"]?.string?.lowercased()
                let kind: ProviderStatus.Kind =
                    switch groupName {
                    case "complete": .done
                    case "in progress": .active
                    case "to-do": .todo
                    default: group == 0 ? .todo : group == groups.count - 1 ? .done : .active
                    }
                return ProviderStatus(name: name, kind: kind)
            }
        }
    }

    // MARK: Writing

    /// The page properties for the changed fields.
    public static func properties(
        of task: TaskItem, _ changes: Set<ExternalItem.Field>, schema: Schema, connection: ProviderConnection,
        calendar: Calendar
    ) -> [String: JSONValue] {
        var properties: [String: JSONValue] = [:]
        if changes.contains(.title) {
            properties[schema.title] = .object([
                "title": .array([.object(["text": .object(["content": .string(task.title)])])])
            ])
        }
        if let date = schema.date, !changes.isDisjoint(with: [.date, .minute, .dueDate]) {
            func text(_ day: LocalDate?, _ minute: Int?) -> JSONValue {
                guard let day else { return .null }
                return .string(
                    minute.map { ExternalItem.instantText(day: day, minute: $0, calendar: calendar) } ?? day.description
                )
            }
            let scheduled = text(task.scheduledDate, task.scheduledMinute)
            if connection.dateMapping == .start {
                let due = text(task.dueDate, nil)
                // A range needs its start; a due date alone becomes the start.
                properties[date] =
                    scheduled == .null
                    ? (due == .null ? .object(["date": .null]) : .object(["date": .object(["start": due])]))
                    : .object(["date": .object(["start": scheduled, "end": due])])
            } else {
                properties[date] = .object(["date": scheduled == .null ? .null : .object(["start": scheduled])])
            }
        }
        if let status = schema.status, !changes.isDisjoint(with: [.done, .column]),
            let target = connection.status(for: task.bucket, isDone: task.isDone)
        {
            properties[status] = .object([schema.statusType: .object(["name": .string(target.name)])])
        }
        if changes.contains(.subtasks) {
            for subtask in task.subtasks where schema.checkboxes.contains(subtask.title) {
                properties[subtask.title] = .object(["checkbox": .bool(subtask.isDone)])
            }
        }
        return properties
    }
}

extension ExternalItem {
    /// A Notion page, read through its data source's schema. With due mapping a date range's end schedules it,
    /// or its start when there's no end; with start mapping the start schedules it and the end is the due date.
    public init(
        _ page: Notion.Page, schema: Notion.Schema, ownerID: String?, connection: ProviderConnection, calendar: Calendar
    ) {
        func day(_ value: JSONValue?) -> (day: LocalDate, minute: Int?)? {
            guard let text = value?.string else { return nil }
            if text.count > 10, let instant = ExternalItem.instant(text) {
                let schedule = ExternalItem.schedule(at: instant, calendar: calendar)
                return (schedule.day, schedule.minute)
            }
            return LocalDate(iso: String(text.prefix(10))).map { ($0, nil) }
        }
        let properties = page.properties
        let title = (properties[schema.title]?["title"]?.array ?? []).compactMap { $0["plain_text"]?.string }.joined()
        let range = schema.date.flatMap { properties[$0]?["date"] }
        let start = day(range?["start"])
        let end = day(range?["end"])
        let scheduled = connection.dateMapping == .start ? start : end ?? start
        let statusName = schema.status.flatMap { properties[$0]?[schema.statusType]?["name"]?.string }
        let status = statusName.map { name in
            schema.statuses.first { $0.name == name } ?? ProviderStatus(name: name, kind: .todo)
        }
        let target = status.map(connection.target) ?? .byDate
        let people = schema.people.flatMap { properties[$0]?["people"]?.array } ?? []
        self.init(
            id: page.id, title: title, date: scheduled?.day, minute: scheduled?.minute,
            dueDate: connection.dateMapping == .start ? end?.day : nil, isDone: target == .done,
            isDeleted: page.inTrash == true, isMine: people.isEmpty || people.contains { $0["id"]?.string == ownerID },
            updatedAt: page.lastEditedTime.flatMap(ExternalItem.instant), url: page.url.flatMap(URL.init),
            bucket: target.bucket,
            subtasks: schema.checkboxes.map { name in
                Subtask(id: "\(page.id):\(name)", title: name, isDone: properties[name]?["checkbox"] == .bool(true))
            })
    }
}
