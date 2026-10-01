import Foundation

/// What either brain answers (FEATURES §4.19): a short reply, tasks to add and changes to existing tasks. Names
/// and relative days stay as words here; `AssistantResolver` turns them into a preview against the board.
public struct AssistantPlan: Codable, Equatable, Sendable {
    public struct NewTask: Codable, Equatable, Sendable {
        public var title: String
        public var list: String?
        public var day: String?
        public var time: String?
        public var estimateMinutes: Int?
        public var notes: String?
        public var subtasks: [String]?

        public init(
            title: String, list: String? = nil, day: String? = nil, time: String? = nil,
            estimateMinutes: Int? = nil, notes: String? = nil, subtasks: [String]? = nil
        ) {
            self.title = title
            self.list = list
            self.day = day
            self.time = time
            self.estimateMinutes = estimateMinutes
            self.notes = notes
            self.subtasks = subtasks
        }

        enum CodingKeys: String, CodingKey {
            case title, list, day, time, notes, subtasks
            case estimateMinutes = "estimate_minutes"
        }
    }

    public struct Edit: Codable, Equatable, Sendable {
        /// The task's title as the user named it, with or without the @.
        public var task: String
        public var title: String?
        public var list: String?
        public var column: String?
        public var day: String?
        public var time: String?
        public var estimateMinutes: Int?
        public var notes: String?
        public var addSubtasks: [String]?
        public var logMinutes: Int?
        public var done: Bool?

        public init(
            task: String, title: String? = nil, list: String? = nil, column: String? = nil, day: String? = nil,
            time: String? = nil, estimateMinutes: Int? = nil, notes: String? = nil, addSubtasks: [String]? = nil,
            logMinutes: Int? = nil, done: Bool? = nil
        ) {
            self.task = task
            self.title = title
            self.list = list
            self.column = column
            self.day = day
            self.time = time
            self.estimateMinutes = estimateMinutes
            self.notes = notes
            self.addSubtasks = addSubtasks
            self.logMinutes = logMinutes
            self.done = done
        }

        enum CodingKeys: String, CodingKey {
            case task, title, list, column, day, time, notes, done
            case estimateMinutes = "estimate_minutes"
            case addSubtasks = "add_subtasks"
            case logMinutes = "log_minutes"
        }
    }

    public var reply: String
    public var add: [NewTask]
    public var edit: [Edit]

    public init(reply: String, add: [NewTask] = [], edit: [Edit] = []) {
        self.reply = reply
        self.add = add
        self.edit = edit
    }

    /// The same shape as JSON Schema, for Claude's structured output. Every field is required and nullable, as
    /// strict schemas want.
    public static var jsonSchema: JSONValue {
        func nullable(_ type: String) -> JSONValue { ["type": [.string(type), "null"]] }
        let strings: JSONValue = ["type": "array", "items": ["type": "string"]]
        let newTask: JSONValue = [
            "type": "object", "additionalProperties": false,
            "required": ["title", "list", "day", "time", "estimate_minutes", "notes", "subtasks"],
            "properties": [
                "title": ["type": "string"], "list": nullable("string"), "day": nullable("string"),
                "time": nullable("string"), "estimate_minutes": nullable("integer"), "notes": nullable("string"),
                "subtasks": strings,
            ],
        ]
        let edit: JSONValue = [
            "type": "object", "additionalProperties": false,
            "required": [
                "task", "title", "list", "column", "day", "time", "estimate_minutes", "notes", "add_subtasks",
                "log_minutes", "done",
            ],
            "properties": [
                "task": ["type": "string"], "title": nullable("string"), "list": nullable("string"),
                "column": ["type": ["string", "null"], "enum": ["backlog", "week", "today", nil]],
                "day": nullable("string"), "time": nullable("string"), "estimate_minutes": nullable("integer"),
                "notes": nullable("string"), "add_subtasks": strings, "log_minutes": nullable("integer"),
                "done": nullable("boolean"),
            ],
        ]
        return [
            "type": "object", "additionalProperties": false, "required": ["reply", "add", "edit"],
            "properties": [
                "reply": ["type": "string"], "add": ["type": "array", "items": newTask],
                "edit": ["type": "array", "items": edit],
            ],
        ]
    }
}
