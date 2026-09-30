import Foundation

/// Overview's three "Most productive" cards (FEATURES §4.14).
public struct Productivity: Equatable, Sendable {
    /// Work per hour of the day, midnight first, over the range.
    public var hours: [TimeInterval]
    /// Tasks done and work per weekday, in the week's order from `firstWeekday`.
    public var weekdays: [Weekday]
    /// Work per month of the range's last year, January to that month.
    public var months: [TimeInterval]

    public struct Weekday: Equatable, Sendable {
        /// 1 is Sunday, as in `Calendar`.
        public var weekday: Int
        public var tasksDone: Int
        public var work: TimeInterval
        /// Early or on time among finished tasks with an estimate; nil when none had one.
        public var onEstimate: Double?
        /// Every day of the range it falls on is still ahead, like Sunday in a week in progress.
        public var isAhead: Bool
    }

    public init(_ data: ReportData, range: ReportRange, firstWeekday: Int = 2) {
        let calendar = data.calendar
        let days = range.days(calendar: calendar)
        var hours = Array(repeating: TimeInterval(0), count: 24)
        for day in days {
            for hour in 0..<24 {
                let start = day.startOfDay(in: calendar).addingTimeInterval(TimeInterval(hour * 3600))
                hours[hour] += data.work(in: DateInterval(start: start, duration: 3600))
            }
        }
        self.hours = hours

        let order = (0..<7).map { (firstWeekday - 1 + $0) % 7 + 1 }
        weekdays = order.map { weekday in
            let matching = days.filter { calendar.component(.weekday, from: $0.startOfDay(in: calendar)) == weekday }
            let done = matching.flatMap { data.done(in: data.interval(of: $0)) }
            let past = matching.filter { $0.startOfDay(in: calendar) <= data.now }
            return Weekday(
                weekday: weekday, tasksDone: done.count,
                work: matching.reduce(0) { $0 + data.work(in: data.interval(of: $1)) },
                onEstimate: DaySummary(doneToday: done, now: data.now).onEstimate, isAhead: past.isEmpty)
        }

        months = (1...range.last.month).map { month in
            let first = LocalDate(year: range.last.year, month: month, day: 1)
            let next =
                month == 12
                ? LocalDate(year: range.last.year + 1, month: 1, day: 1)
                : LocalDate(
                    year: range.last.year, month: month + 1, day: 1)
            return data.work(
                in: DateInterval(start: first.startOfDay(in: calendar), end: next.startOfDay(in: calendar)))
        }
    }

    /// The hour with the most work, nil when nothing was worked.
    public var bestHour: Int? { best(hours) }
    public var bestWeekday: Weekday? {
        let worked = weekdays.filter { $0.tasksDone > 0 || $0.work > 0 }
        return worked.max { ($0.tasksDone, $0.work) < ($1.tasksDone, $1.work) }
    }
    /// 1 is January.
    public var bestMonth: Int? { best(months).map { $0 + 1 } }

    private func best(_ values: [TimeInterval]) -> Int? {
        guard let peak = values.max(), peak > 0 else { return nil }
        return values.firstIndex(of: peak)
    }
}

extension ReportRange {
    /// What a range is measured against: Today against the same weekday a week earlier ("vs last Sat"), any other
    /// range against the same number of days just before.
    public func compared(to period: ReportPeriod, calendar: Calendar) -> ReportRange {
        if case .today = period {
            let day = first.adding(days: -7, calendar: calendar)
            return ReportRange(first: day, last: day)
        }
        return previous(calendar: calendar)
    }
}
