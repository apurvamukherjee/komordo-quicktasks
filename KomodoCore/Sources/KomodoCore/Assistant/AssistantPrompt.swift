import Foundation

/// What both brains are told: the job, the plan's rules, and the board right now. Shared, so the on-device model
/// and Claude answer the same way.
public enum AssistantPrompt {
    /// Enough open tasks to match names against without flooding a small model's context.
    static let taskLimit = 60

    public static func instructions(for context: AssistantContext) -> String {
        // English whatever the Mac's language, like the rest of the prompt.
        let weekday = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][
            context.calendar.component(.weekday, from: context.now) - 1]
        let lists = context.lists.map(\.name).joined(separator: ", ")
        let names = Dictionary(context.lists.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let tasks = context.tasks.filter { !$0.isDone }.prefix(taskLimit).map { task in
            var line = "- \(task.title) [\(names[task.listID] ?? "?"), \(task.column(in: context.week).rawValue)"
            if let day = task.scheduledDate { line += ", \(day)" }
            return line + "]"
        }
        return """
            You are Komodo's assistant inside a to-do app. Turn what the user writes into a plan; the app shows it \
            as a preview the user confirms, so never claim anything is already saved.

            Rules:
            - "add" holds new tasks. Split a brain dump into one task per thing to do. Keep titles short and \
            start them with a verb when natural.
            - "edit" holds changes to existing tasks. "task" is the task's title as listed below; the user marks \
            one with @, like @Review accounts. Use log_minutes to log time, done to finish it, column to move it.
            - day is a word or a date: today, tomorrow, a weekday like fri, next week, or YYYY-MM-DD. Leave it \
            null for no date. time is like 07:00 or 7pm, only when the user gives one.
            - estimate_minutes only when the user says how long ("1h" is 60, "(3h)" is 180).
            - list is one of the lists below, or null for the current list.
            - reply is one or two short, friendly sentences about what you propose. No emoji.
            - If the request isn't about tasks, reply briefly and leave add and edit empty.

            Today is \(weekday), \(context.today). Lists: \(lists.isEmpty ? "none" : lists).
            Open tasks:
            \(tasks.isEmpty ? "(none)" : tasks.joined(separator: "\n"))
            """
    }
}
