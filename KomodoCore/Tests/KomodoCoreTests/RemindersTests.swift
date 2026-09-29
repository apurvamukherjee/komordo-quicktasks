import Foundation
import Testing

@testable import KomodoCore

struct RemindersTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return calendar
    }()

    private let today = LocalDate(year: 2026, month: 9, day: 26)

    private func task(
        _ id: String, minute: Int?, reminds: Bool = true, done: Bool = false, rule: RepeatRule? = nil
    ) -> TaskItem {
        TaskItem(
            id: id, listID: "work", title: id, bucket: .today, rank: 0, scheduledDate: today, scheduledMinute: minute,
            repeatRule: rule, remindsAtStart: reminds, completedAt: done ? Date(timeIntervalSince1970: 0) : nil)
    }

    @Test func remindsOpenTimedTasksAfterNowSoonestFirst() {
        let now = today.startOfDay(in: calendar).addingTimeInterval(14 * 3600)
        let tasks = [
            task("later", minute: 16 * 60),
            task("soon", minute: 15 * 60),
            task("past", minute: 9 * 60),
            task("allDay", minute: nil),
            task("muted", minute: 15 * 60, reminds: false),
            task("done", minute: 15 * 60, done: true),
            task("rule", minute: 15 * 60, rule: RepeatRule(unit: .week)),
        ]
        let reminders = Reminders.upcoming(in: tasks, after: now, calendar: calendar)
        #expect(reminders.map(\.taskID) == ["soon", "later"])
        #expect(reminders.first?.date == today.startOfDay(in: calendar).addingTimeInterval(15 * 3600))
    }

    @Test func keepsWithinTheSystemLimit() {
        let now = today.startOfDay(in: calendar)
        let tasks = (1...100).map { task("t\($0)", minute: $0) }
        #expect(Reminders.upcoming(in: tasks, after: now, calendar: calendar).count == Reminders.limit)
    }
}
