import Foundation

/// Where the end-of-day review sends a task that wasn't finished (FEATURES §6.4, DESIGN_SYSTEM §13.11).
public enum CarryOver: CaseIterable, Sendable {
    case tomorrow
    case thisWeek

    /// Tomorrow dates the task for the next day and keeps its time, so a 3 PM call stays at 3 PM. This week
    /// parks it in This week without a date, as a drag there would.
    public func apply(to task: inout TaskItem, today: LocalDate, calendar: Calendar) {
        switch self {
        case .tomorrow:
            task.scheduledDate = today.adding(days: 1, calendar: calendar)
        case .thisWeek:
            task.bucket = .week
            task.scheduledDate = nil
            task.scheduledMinute = nil
        }
    }
}
