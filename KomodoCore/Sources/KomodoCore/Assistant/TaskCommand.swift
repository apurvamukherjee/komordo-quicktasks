import Foundation

/// `@Task` commands read straight from the user's words (FEATURES §4.19): "move @Draft launch email to tomorrow",
/// "log 30min on @Gym", "@Review accounts is done". They're precise enough to need no model, and the on-device
/// model garbled them, so these edits win over the model's for the same task.
enum TaskCommand {
    static func edits(in phrases: [RequestPhrase], tasks: [TaskItem], lists: [TaskList]) -> [AssistantPlan.Edit] {
        phrases.compactMap { phrase in
            guard let task = mentioned(in: phrase.text, tasks: tasks) else { return nil }
            let text = phrase.text
            var edit = AssistantPlan.Edit(task: task.title)
            let rest = text.components(separatedBy: "@" + task.title.lowercased()).last ?? ""
            if text.hasPrefix("rename"), rest.contains(" to "),
                let range = phrase.original.range(of: " to ", options: [.caseInsensitive, .backwards])
            {
                edit.title = phrase.original[range.upperBound...].trimmingCharacters(in: .whitespaces)
                return edit
            }
            if let minutes = phrase.minutes {
                if text.contains("log") || text.contains("spent") || text.contains("worked") {
                    edit.logMinutes = minutes
                } else {
                    edit.estimateMinutes = minutes
                }
            }
            edit.day = phrase.day
            edit.time = phrase.minute.map { String(format: "%02d:%02d", $0 / 60, $0 % 60) }
            if text.contains("backlog") {
                edit.column = Bucket.backlog.rawValue
            } else if text.contains("this week") {
                edit.column = Bucket.week.rawValue
            }
            if ["done", "finish", "complete", "tick off", "mark off"].contains(where: { text.contains($0) }) {
                edit.done = true
            }
            edit.list = lists.first { rest.contains(" to " + $0.name.lowercased()) }?.name
            return edit
        }
    }

    /// The task an @ names: the longest title the text after the @ starts with, so "@Plan the offsite" beats
    /// "@Plan".
    static func mentioned(in text: String, tasks: [TaskItem]) -> TaskItem? {
        guard let at = text.firstIndex(of: "@") else { return nil }
        let after = text[text.index(after: at)...]
        let open = tasks.filter { !$0.isDone } + tasks.filter(\.isDone)
        return open.filter { after.hasPrefix($0.title.lowercased()) }.max { $0.title.count < $1.title.count }
            ?? open.first { title in
                let first = after.split(separator: " ").prefix(2).joined(separator: " ")
                return !first.isEmpty && title.title.lowercased().hasPrefix(first)
            }
    }
}
