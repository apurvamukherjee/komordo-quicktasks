import Foundation

/// A scheduled task's reminder at its start time (FEATURES §4.12).
public struct Reminder: Equatable, Sendable {
    public var taskID: String
    public var title: String
    public var date: Date
}

public enum Reminders {
    /// macOS keeps 64 pending notifications per app; the rest wait for a later sync to move up.
    public static let limit = 60

    /// Open tasks with a time and Remind at start, soonest first, after `now`. Repeat parents are rules, so
    /// only their copies remind.
    public static func upcoming(in tasks: [TaskItem], after now: Date, calendar: Calendar) -> [Reminder] {
        let reminders = tasks.compactMap { task -> Reminder? in
            guard task.remindsAtStart, task.completedAt == nil, task.repeatRule == nil,
                let day = task.scheduledDate, let minute = task.scheduledMinute,
                let date = calendar.date(byAdding: .minute, value: minute, to: day.startOfDay(in: calendar)),
                date > now
            else { return nil }
            return Reminder(taskID: task.id, title: task.title, date: date)
        }
        return Array(reminders.sorted { $0.date < $1.date }.prefix(limit))
    }
}
