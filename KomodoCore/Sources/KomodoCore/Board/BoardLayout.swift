import Foundation

/// The Board's columns for one list or for all lists, derived from tasks and the date (FEATURES §4.2).
/// Nothing here is stored; the Board recomputes it whenever tasks or the day change.
public struct BoardLayout: Sendable {
    public var backlog: [TaskItem]
    public var week: [TaskItem]
    /// Today's focus queue: open Today tasks with no time today, in priority order. Overdue tasks land here, and
    /// timed tasks whose time has passed go first, by time (FEATURES §4.6).
    public var upNext: [TaskItem]
    /// Today's tasks with a time still ahead, sorted by that time.
    public var scheduledToday: [TaskItem]
    /// Completed today, oldest first.
    public var doneToday: [TaskItem]

    /// Without `now`, every timed task today stays in Scheduled, whatever the hour.
    public init(tasks: [TaskItem], listID: String? = nil, week: WeekRange, now: Date? = nil, calendar: Calendar) {
        let inScope = tasks.filter { listID == nil || $0.listID == listID }
        let open = inScope.filter { !$0.isDone }
        let byRank: (TaskItem, TaskItem) -> Bool = { $0.rank < $1.rank }

        backlog = open.filter { $0.column(in: week) == .backlog }.sorted(by: byRank)

        // Dated tasks later this week sit below the ones placed by hand.
        let thisWeek = open.filter { $0.column(in: week) == .week }
        self.week =
            thisWeek.filter { $0.scheduledDate == nil }.sorted(by: byRank)
            + thisWeek.filter { $0.scheduledDate != nil }.sorted(by: BoardLayout.bySchedule)

        let today = open.filter { $0.column(in: week) == .today }
        let isTimedToday: (TaskItem) -> Bool = { $0.scheduledDate == week.today && $0.scheduledMinute != nil }
        let timed = today.filter(isTimedToday).sorted(by: BoardLayout.bySchedule)
        let hasStarted: (TaskItem) -> Bool = { task in
            guard let now, let start = task.scheduledStart(calendar: calendar) else { return false }
            return start <= now
        }
        upNext = timed.filter(hasStarted) + today.filter { !isTimedToday($0) }.sorted(by: byRank)
        scheduledToday = timed.filter { !hasStarted($0) }

        let dayStart = week.today.startOfDay(in: calendar)
        let dayEnd = week.today.adding(days: 1, calendar: calendar).startOfDay(in: calendar)
        doneToday =
            inScope
            .filter { task in task.completedAt.map { $0 >= dayStart && $0 < dayEnd } ?? false }
            .sorted { ($0.completedAt ?? dayStart) < ($1.completedAt ?? dayStart) }
    }

    /// Everything still open in Today, scheduled or not.
    public var openToday: [TaskItem] { upNext + scheduledToday }

    private static func bySchedule(_ lhs: TaskItem, _ rhs: TaskItem) -> Bool {
        let left = (lhs.scheduledDate ?? LocalDate(year: 9999, month: 1, day: 1), lhs.scheduledMinute ?? -1)
        let right = (rhs.scheduledDate ?? LocalDate(year: 9999, month: 1, day: 1), rhs.scheduledMinute ?? -1)
        if left.0 != right.0 { return left.0 < right.0 }
        if left.1 != right.1 { return left.1 < right.1 }
        return lhs.rank < rhs.rank
    }
}
