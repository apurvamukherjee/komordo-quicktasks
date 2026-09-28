import Foundation

/// Recurring tasks (FEATURES §4.7). A parent holds the rule and stays in Backlog; each day the rule lands on in
/// the current week gets a child, a normal scheduled task. Children are made on launch, at midnight and on
/// Monday, and each has an ID derived from its parent and date, so making them twice never duplicates.
public enum Recurrence {
    public static func childID(parentID: String, date: LocalDate) -> String { "\(parentID)@\(date)" }

    /// The children `parent` should have in `week`, whether or not they exist yet.
    public static func children(of parent: TaskItem, in week: WeekRange, calendar: Calendar) -> [TaskItem] {
        guard let rule = parent.repeatRule, let start = parent.repeatStart else { return [] }
        return rule.occurrences(in: week.days, from: start, calendar: calendar).map { date in
            var child = parent
            child.id = childID(parentID: parent.id, date: date)
            child.repeatParentID = parent.id
            child.repeatRule = nil
            child.repeatStart = nil
            child.scheduledDate = date
            child.bucket = .week
            child.completedAt = nil
            child.sessions = []
            child.editedAt = nil
            child.subtasks = parent.subtasks.enumerated().map { index, subtask in
                Subtask(id: "\(child.id)#\(index)", title: subtask.title)
            }
            return child
        }
    }

    /// `tasks` plus every child due this week that's missing. Existing children stay as they are, even when
    /// edited or moved. `dismissed` holds children deleted by hand, so they don't come back.
    public static func expanding(
        _ tasks: [TaskItem], in week: WeekRange, dismissed: Set<String> = [], calendar: Calendar
    ) -> [TaskItem] {
        let existing = Set(tasks.map(\.id))
        let missing = tasks.filter(\.isRecurringParent).flatMap { children(of: $0, in: week, calendar: calendar) }
            .filter { !existing.contains($0.id) && !dismissed.contains($0.id) }
        return tasks + missing
    }

    /// Drops the unfinished children of `parentID`, for **Replace existing tasks** and **Delete existing tasks**.
    /// Finished ones stay, since they're history.
    public static func removingUnfinishedChildren(of parentID: String, from tasks: [TaskItem]) -> [TaskItem] {
        tasks.filter { $0.repeatParentID != parentID || $0.isDone }
    }
}

extension TaskItem {
    /// Holds a repeat rule and makes the children; it isn't a child itself.
    public var isRecurringParent: Bool { repeatRule != nil && repeatParentID == nil }
}
