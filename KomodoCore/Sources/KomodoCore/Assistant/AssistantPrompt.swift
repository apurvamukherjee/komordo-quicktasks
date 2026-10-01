import Foundation

/// What both brains are told: the job, the plan's rules, and the board right now. Shared, so the on-device model
/// and Claude answer the same way.
public enum AssistantPrompt {
    /// Enough open tasks to match names against without flooding a small model's context.
    static let taskLimit = 60

    /// Only the tasks the request names are listed, or every open task when it uses @: listing the whole board
    /// tempted the on-device model to rewrite tasks instead of adding new ones.
    public static func instructions(for context: AssistantContext, request: String) -> String {
        // English whatever the Mac's language, like the rest of the prompt.
        let weekday = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][
            context.calendar.component(.weekday, from: context.now) - 1]
        let lists = context.lists.map(\.name).joined(separator: ", ")
        let names = Dictionary(context.lists.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let words = request.lowercased()
        let named = context.tasks.filter {
            !$0.isDone && (words.contains("@") || words.contains($0.title.lowercased()))
        }
        // Titles alone, quoted: the on-device model copied any annotation into the titles it wrote.
        let tasks = named.prefix(taskLimit).map { "- \"\($0.title)\" in \(names[$0.listID] ?? "a list")" }
        return """
            You are Komodo's assistant inside a to-do app. Turn what the user writes into a plan; the app shows it \
            as a preview the user confirms, so never claim anything is already saved.

            Rules:
            - "add" holds new tasks. Split a brain dump into one task per thing to do: each phrase between \
            commas, "and" or new lines is usually its own task, so don't drop any. Keep the user's wording for \
            titles, starting with the verb they used.
            - Only fill day, time, estimate_minutes and list when the user said them for that task; otherwise null.
            - "edit" holds changes to existing tasks, and only ones the user names, usually with @, like \
            @Review accounts. "task" is that name. Never edit a task the user didn't name; when unsure, add a new \
            task instead. Use log_minutes to log time, done to finish it, column to move it.
            - day is a word or a date: today, tomorrow, a weekday like fri, next week, or YYYY-MM-DD. Leave it \
            null for no date. time is like 07:00 or 7pm, only when the user gives one.
            - estimate_minutes only when the user says how long ("1h" is 60, "(3h)" is 180).
            - list is one of the lists below, or null for the current list.
            - reply is one or two short, friendly sentences about what you propose. No emoji.
            - If the request isn't about tasks, reply briefly and leave add and edit empty.

            Today is \(weekday), \(context.today). Lists: \(lists.isEmpty ? "none" : lists).
            Existing tasks the user named:
            \(tasks.isEmpty ? "(none, so everything is a new task)" : tasks.joined(separator: "\n"))
            """
    }
}
