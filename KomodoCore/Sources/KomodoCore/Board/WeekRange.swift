import Foundation

/// The seven days of the week containing `today`. Weeks start on Monday by default (FEATURES §4.2).
public struct WeekRange: Hashable, Sendable {
    public var today: LocalDate
    public var start: LocalDate
    public var days: [LocalDate]

    public var end: LocalDate { days.last ?? start }

    /// `firstWeekday` uses `Calendar` numbering: 1 is Sunday, 2 is Monday.
    public init(containing today: LocalDate, firstWeekday: Int = 2, calendar: Calendar) {
        self.today = today
        let weekday = calendar.component(.weekday, from: today.startOfDay(in: calendar))
        let offset = (weekday - firstWeekday + 7) % 7
        let start = today.adding(days: -offset, calendar: calendar)
        self.start = start
        self.days = (0..<7).map { start.adding(days: $0, calendar: calendar) }
    }
}
