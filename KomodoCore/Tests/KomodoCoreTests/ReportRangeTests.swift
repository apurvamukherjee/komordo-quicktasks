import Foundation
import Testing

@testable import KomodoCore

struct ReportRangeTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return calendar
    }()

    // Saturday, Sep 26 2026, as on Reports.png.
    private let today = LocalDate(year: 2026, month: 9, day: 26)

    @Test func sevenDaysIsThisWeekMondayToSunday() {
        let range = ReportRange(.week, today: today, calendar: calendar)
        #expect(range.first == LocalDate(year: 2026, month: 9, day: 21))
        #expect(range.last == LocalDate(year: 2026, month: 9, day: 27))
        #expect(range.days(calendar: calendar).count == 7)
    }

    @Test func thirtyDaysEndsToday() {
        let range = ReportRange(.month, today: today, calendar: calendar)
        #expect(range.first == LocalDate(year: 2026, month: 8, day: 28))
        #expect(range.last == today)
    }

    @Test func thePreviousRangeHasTheSameLengthJustBefore() {
        let range = ReportRange(.week, today: today, calendar: calendar).previous(calendar: calendar)
        #expect(range.first == LocalDate(year: 2026, month: 9, day: 14))
        #expect(range.last == LocalDate(year: 2026, month: 9, day: 20))
    }

    @Test func aCustomRangeInOrder() {
        let range = ReportRange(
            .custom(today, LocalDate(year: 2026, month: 9, day: 1)), today: today, calendar: calendar)
        #expect(range.first == LocalDate(year: 2026, month: 9, day: 1))
        #expect(range.interval(calendar: calendar).duration == 26 * 86_400)
    }
}
