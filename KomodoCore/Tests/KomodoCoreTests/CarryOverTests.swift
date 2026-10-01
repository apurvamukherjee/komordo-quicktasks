import Foundation
import Testing

@testable import KomodoCore

struct CarryOverTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
    // A Thursday, so tomorrow is still this week.
    private let today = LocalDate(year: 2026, month: 10, day: 1)

    private var timedToday: TaskItem {
        TaskItem(
            id: "call", listID: "work", title: "Call with Apurva", bucket: .today, rank: 0, scheduledDate: today,
            scheduledMinute: 15 * 60)
    }

    @Test func tomorrowKeepsTheTime() {
        var task = timedToday
        CarryOver.tomorrow.apply(to: &task, today: today, calendar: calendar)
        #expect(task.scheduledDate == LocalDate(year: 2026, month: 10, day: 2))
        #expect(task.scheduledMinute == 15 * 60)
        let week = WeekRange(containing: today, firstWeekday: 2, calendar: calendar)
        #expect(task.column(in: week) == .week)
    }

    @Test func thisWeekParksItUndated() {
        var task = timedToday
        CarryOver.thisWeek.apply(to: &task, today: today, calendar: calendar)
        #expect(task.bucket == .week)
        #expect(task.scheduledDate == nil)
        #expect(task.scheduledMinute == nil)
    }
}
