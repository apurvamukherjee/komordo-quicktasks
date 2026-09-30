import Foundation

/// The date range every report filters by (FEATURES §4.14): Today, 7 days, 30 days or a custom span.
public enum ReportPeriod: Hashable, Sendable {
    case today
    /// The current week, Monday to Sunday by default, as `Reports.png` draws it, days ahead included.
    case week
    /// The 30 days ending today.
    case month
    case custom(LocalDate, LocalDate)
}

/// A span of whole days, first to last inclusive.
public struct ReportRange: Hashable, Sendable {
    public var first: LocalDate
    public var last: LocalDate

    public init(first: LocalDate, last: LocalDate) {
        self.first = min(first, last)
        self.last = max(first, last)
    }

    public init(_ period: ReportPeriod, today: LocalDate, firstWeekday: Int = 2, calendar: Calendar) {
        switch period {
        case .today:
            self.init(first: today, last: today)
        case .week:
            let week = WeekRange(containing: today, firstWeekday: firstWeekday, calendar: calendar)
            self.init(first: week.start, last: week.end)
        case .month:
            self.init(first: today.adding(days: -29, calendar: calendar), last: today)
        case .custom(let first, let last):
            self.init(first: first, last: last)
        }
    }

    public func days(calendar: Calendar) -> [LocalDate] {
        var days: [LocalDate] = []
        var day = first
        while day <= last {
            days.append(day)
            day = day.adding(days: 1, calendar: calendar)
        }
        return days
    }

    /// The same number of days just before, for "vs last week".
    public func previous(calendar: Calendar) -> ReportRange {
        let count = days(calendar: calendar).count
        return ReportRange(
            first: first.adding(days: -count, calendar: calendar), last: first.adding(days: -1, calendar: calendar))
    }

    /// Midnight before the first day to midnight after the last.
    public func interval(calendar: Calendar) -> DateInterval {
        DateInterval(
            start: first.startOfDay(in: calendar),
            end: last.adding(days: 1, calendar: calendar).startOfDay(in: calendar))
    }
}
