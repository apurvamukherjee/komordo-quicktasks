import Foundation

/// Projections for the Today column (ARCHITECTURE §4.2): when each queued task should start, when the day
/// should end, and the numbers in the day meter. Derived from the queue, never stored.
public struct DayPlan: Sendable {
    /// Projected start for each task in `queue`, in order.
    public var startTimes: [Date]
    public var endsAround: Date
    public var estimateLeft: TimeInterval
    public var done: Int
    public var total: Int
    public var focused: TimeInterval
    /// When work on today's finished tasks began and when the last one was done, for the day summary.
    public var firstStart: Date?
    public var lastFinish: Date?

    /// - Parameters:
    ///   - live: the task whose timer runs, if any; it goes first and isn't part of `queue`.
    ///   - queue: the rest of Up next, in order.
    ///   - scheduled: open tasks with a time today. They count toward the day but not the queue's start times.
    ///   - allTasks: every task, to sum today's focused time across lists.
    public init(
        now: Date, live: TaskItem?, queue: [TaskItem], scheduled: [TaskItem], doneToday: [TaskItem],
        allTasks: [TaskItem], today: LocalDate, calendar: Calendar
    ) {
        var cursor = now.addingTimeInterval(live?.remaining(at: now) ?? 0)
        var starts: [Date] = []
        for task in queue {
            starts.append(cursor)
            cursor = cursor.addingTimeInterval(task.remaining(at: now))
        }
        startTimes = starts

        let scheduledLeft = scheduled.reduce(0) { $0 + $1.remaining(at: now) }
        endsAround = cursor.addingTimeInterval(scheduledLeft)

        let open = (live.map { [$0] } ?? []) + queue + scheduled
        estimateLeft = open.reduce(0) { $0 + $1.remaining(at: now) }
        done = doneToday.count
        total = doneToday.count + open.count

        let dayStart = today.startOfDay(in: calendar)
        // A task started last night and finished today counts from midnight, like its focused time.
        firstStart = doneToday.flatMap(\.sessions).map { max($0.start, dayStart) }.min()
        lastFinish = doneToday.compactMap(\.completedAt).max()
        focused = allTasks.reduce(0) { sum, task in
            sum
                + task.sessions.reduce(0) { partial, session in
                    // Only the part of each session that falls on today counts.
                    let start = max(session.start, dayStart)
                    let end = session.end ?? now
                    return partial + max(0, end.timeIntervalSince(start))
                }
        }
    }
}
