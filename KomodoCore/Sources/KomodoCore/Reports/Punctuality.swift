import Foundation

/// The Punctuality report (FEATURES §4.14, DESIGN_SYSTEM §13.13): finished tasks' time against their estimates.
public struct Punctuality: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        public var taskID: String
        public var title: String
        public var listID: String
        public var estimate: TimeInterval
        public var actual: TimeInterval
        /// Positive when it ran over.
        public var delta: TimeInterval { actual - estimate }
    }

    public struct Week: Equatable, Sendable {
        public var start: LocalDate
        /// Early or on time, nil for a week with no measured tasks.
        public var accuracy: Double?
    }

    public var summary: DaySummary
    /// Largest overrun first.
    public var rows: [Row]
    /// The last eight weeks up to the range's end, oldest first.
    public var weeks: [Week]

    public init(_ data: ReportData, range: ReportRange, firstWeekday: Int = 2, weekCount: Int = 8) {
        let calendar = data.calendar
        let done = data.done(in: range.interval(calendar: calendar))
        summary = DaySummary(doneToday: done, now: data.now)
        rows =
            done
            .compactMap { task in
                guard let estimate = task.estimate, estimate > 0 else { return nil }
                return Row(
                    taskID: task.id, title: task.title, listID: task.listID, estimate: estimate,
                    actual: task.timeTaken(at: data.now))
            }
            .sorted { $0.delta > $1.delta }
        let lastWeek = WeekRange(containing: range.last, firstWeekday: firstWeekday, calendar: calendar)
        weeks = (0..<weekCount).reversed().map { back in
            let start = lastWeek.start.adding(days: -7 * back, calendar: calendar)
            let week = ReportRange(first: start, last: start.adding(days: 6, calendar: calendar))
            return Week(
                start: start,
                accuracy: DaySummary(doneToday: data.done(in: week.interval(calendar: calendar)), now: data.now)
                    .onEstimate)
        }
    }

    public var isEmpty: Bool { summary.measured == 0 }
}
