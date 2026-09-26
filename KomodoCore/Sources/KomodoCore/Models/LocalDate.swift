import Foundation

/// A calendar day with no time or zone, like the schema's `YYYY-MM-DD` columns. Comparing days this way
/// keeps "today" stable across time zones and daylight-saving changes.
public struct LocalDate: Hashable, Comparable, Sendable, CustomStringConvertible {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// Midnight at the start of this day in the calendar's time zone.
    public func startOfDay(in calendar: Calendar) -> Date {
        let components = DateComponents(year: year, month: month, day: day)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    public func adding(days: Int, calendar: Calendar) -> LocalDate {
        let shifted =
            calendar.date(byAdding: .day, value: days, to: startOfDay(in: calendar)) ?? startOfDay(in: calendar)
        return LocalDate(shifted, calendar: calendar)
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}
