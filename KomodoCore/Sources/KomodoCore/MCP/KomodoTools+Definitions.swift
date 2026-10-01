/// `tools/list`: each tool's name, what it's for, and its arguments as JSON Schema (FEATURES §5.1).
extension KomodoTools {
    static let definitions: [JSONValue] = [
        tool("list_lists", "Komodo's lists with their IDs, in sidebar order.", properties: [:]),
        tool(
            "list_tasks",
            "Tasks on the Board, today's column first. Filters combine; without status only open tasks come back.",
            properties: [
                "list_id": string("Only this list."),
                "column": column,
                "date": string("Only tasks scheduled on this day, YYYY-MM-DD."),
                "status": ["type": "string", "enum": ["open", "done", "all"]],
            ]),
        tool(
            "create_task",
            """
            Add a task. Without a column or date it goes to the backlog. A trailing estimate in the title, such \
            as "Write spec 45m", is read like Komodo's quick add.
            """,
            properties: [
                "title": string("The task's title."),
                "list_id": string("Defaults to the first list."),
                "column": column,
                "estimate_minutes": number("How long it should take."),
                "notes": string("Plain text notes."),
                "subtasks": ["type": "array", "items": ["type": "string"], "description": "Subtask titles."],
                "date": string("Schedule it on this day, YYYY-MM-DD. The column follows the date."),
                "time": string("Start time on that day, HH:MM in 24-hour time."),
            ], required: ["title"]),
        tool(
            "update_task",
            """
            Change any field of a task. Moving a dated task to another column clears its date. An empty date or \
            time clears it, and estimate_minutes 0 removes the estimate.
            """,
            properties: [
                "id": string("The task's ID."),
                "title": string("New title."),
                "list_id": string("Move it to this list."),
                "column": column,
                "estimate_minutes": number("New estimate."),
                "notes": string("Replaces the notes."),
                "date": string("YYYY-MM-DD, or empty to unschedule."),
                "time": string("HH:MM, or empty for all day."),
            ], required: ["id"]),
        tool("complete_task", "Mark a task done.", properties: ["id": string("The task's ID.")], required: ["id"]),
        tool(
            "complete_subtask", "Tick off one subtask.",
            properties: ["task_id": string("The task's ID."), "subtask_id": string("The subtask's ID.")],
            required: ["task_id", "subtask_id"]),
        tool(
            "log_time", "Add a work session to a task, ending now unless ended_at says otherwise.",
            properties: [
                "task_id": string("The task's ID."),
                "minutes": number("How long the session was."),
                "ended_at": string("When it ended, ISO 8601."),
            ], required: ["task_id", "minutes"]),
        tool(
            "start_focus", "Make a task live in Komodo: its timer starts and Focus mode opens.",
            properties: ["task_id": string("The task's ID.")], required: ["task_id"]),
    ]

    private static let column: JSONValue = [
        "type": "string", "enum": ["backlog", "week", "today"], "description": "backlog, this week, or today.",
    ]

    private static func tool(
        _ name: String, _ description: String, properties: [String: JSONValue], required: [String] = []
    ) -> JSONValue {
        [
            "name": .string(name), "description": .string(description),
            "inputSchema": [
                "type": "object", "properties": .object(properties), "required": .array(required.map { .string($0) }),
            ],
        ]
    }

    private static func string(_ description: String) -> JSONValue {
        ["type": "string", "description": .string(description)]
    }

    private static func number(_ description: String) -> JSONValue {
        ["type": "number", "description": .string(description)]
    }
}
