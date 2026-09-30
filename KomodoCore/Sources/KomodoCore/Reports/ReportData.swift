import Foundation

/// What every report reads (FEATURES §4.14): the tasks and breaks of one list or all of them. Archived tasks count,
/// since archiving keeps them for reports; tasks in Trash don't.
public struct ReportData: Sendable {
    public let tasks: [TaskItem]
    public let breaks: [BreakSession]
    public let now: Date
    public let calendar: Calendar

    /// A break belongs to a list through the task it paused; with a list picked, breaks without a task drop out.
    public init(tasks: [TaskItem], breaks: [BreakSession], listID: String?, now: Date, calendar: Calendar) {
        let tasks = tasks.filter { listID == nil || $0.listID == listID }
        let taskIDs = Set(tasks.map(\.id))
        self.tasks = tasks
        self.breaks = breaks.filter { listID == nil || $0.taskID.map(taskIDs.contains) == true }
        self.now = now
        self.calendar = calendar
    }

    /// Seconds of work inside `interval`, cutting sessions at its edges; a running session counts up to now.
    public func work(in interval: DateInterval) -> TimeInterval {
        tasks.reduce(0) { sum, task in sum + task.sessions.reduce(0) { $0 + overlap($1.start, $1.end, interval) } }
    }

    public func breakTime(in interval: DateInterval) -> TimeInterval {
        breaks.reduce(0) { $0 + overlap($1.start, min($1.end, now), interval) }
    }

    /// Tasks finished inside `interval`, its end excluded so a midnight finish counts once.
    public func done(in interval: DateInterval) -> [TaskItem] {
        tasks.filter { task in task.completedAt.map { $0 >= interval.start && $0 < interval.end } ?? false }
    }

    func overlap(_ start: Date, _ end: Date?, _ interval: DateInterval) -> TimeInterval {
        let from = max(start, interval.start)
        let to = min(end ?? now, interval.end)
        return max(0, to.timeIntervalSince(from))
    }

    func interval(of day: LocalDate) -> DateInterval {
        ReportRange(first: day, last: day).interval(calendar: calendar)
    }
}

/// Overview's tiles and Daily productivity (DESIGN_SYSTEM §13.12).
public struct ReportOverview: Equatable, Sendable {
    public struct Day: Equatable, Sendable {
        public var date: LocalDate
        public var work: TimeInterval
        public var breaks: TimeInterval
        public var tasksDone: Int
        /// Work and breaks together, the chart's Total session.
        public var session: TimeInterval { work + breaks }
    }

    public var days: [Day]

    public init(_ data: ReportData, range: ReportRange) {
        days = range.days(calendar: data.calendar).map { date in
            let interval = data.interval(of: date)
            return Day(
                date: date, work: data.work(in: interval), breaks: data.breakTime(in: interval),
                tasksDone: data.done(in: interval).count)
        }
    }

    /// Days with any work.
    public var workDays: Int { days.filter { $0.work > 0 }.count }
    public var tasksDone: Int { days.reduce(0) { $0 + $1.tasksDone } }
    public var hours: TimeInterval { days.reduce(0) { $0 + $1.work } }
    /// Work per finished task; nil until something is done.
    public var averagePerTask: TimeInterval? { tasksDone == 0 ? nil : hours / Double(tasksDone) }
    public var isEmpty: Bool { days.allSatisfy { $0.work == 0 && $0.breaks == 0 } }
}
