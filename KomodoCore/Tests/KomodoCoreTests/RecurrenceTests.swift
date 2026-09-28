import Foundation
import Testing

@testable import KomodoCore

struct RecurrenceTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = 2
        return calendar
    }()

    /// Thursday, Oct 1 2026, the date on the Schedule artboard.
    private let thursday = LocalDate(year: 2026, month: 10, day: 1)

    private func date(_ month: Int, _ day: Int) -> LocalDate { LocalDate(year: 2026, month: month, day: day) }

    private func days(from start: LocalDate, count: Int) -> [LocalDate] {
        (0..<count).map { start.adding(days: $0, calendar: calendar) }
    }

    @Test func isoWeekdaysStartOnMonday() {
        #expect(date(9, 28).isoWeekday(calendar: calendar) == 1)
        #expect(thursday.isoWeekday(calendar: calendar) == 4)
        #expect(date(10, 4).isoWeekday(calendar: calendar) == 7)
    }

    @Test func everyDayLandsOnEachDayFromTheStart() {
        let hits = RepeatRule.everyDay.occurrences(in: days(from: date(9, 28), count: 7), from: thursday, calendar: calendar)
        #expect(hits == [thursday, date(10, 2), date(10, 3), date(10, 4)])
    }

    @Test func everyWeekdaySkipsTheWeekend() {
        let hits = RepeatRule.everyWeekday.occurrences(
            in: days(from: date(10, 5), count: 7), from: thursday, calendar: calendar)
        #expect(hits == days(from: date(10, 5), count: 5))
    }

    @Test func weeklyWithoutWeekdaysUsesTheStartDay() {
        let rule = RepeatRule(unit: .week)
        #expect(rule.occurs(on: date(10, 8), from: thursday, calendar: calendar))
        #expect(!rule.occurs(on: date(10, 9), from: thursday, calendar: calendar))
    }

    @Test func everyTwoWeeksSkipsTheWeekBetween() {
        let rule = RepeatRule(interval: 2, unit: .week, weekdays: [2, 4])
        let hits = rule.occurrences(in: days(from: date(9, 28), count: 21), from: thursday, calendar: calendar)
        // Tuesday Sep 29 is before the start; the next week is skipped.
        #expect(hits == [thursday, date(10, 13), date(10, 15)])
    }

    @Test func monthlyKeepsTheDayOfTheMonth() {
        let start = date(1, 31)
        #expect(RepeatRule.monthly.occurs(on: date(3, 31), from: start, calendar: calendar))
        // February has no 31st, so that month is skipped rather than moved.
        #expect(!RepeatRule.monthly.occurs(on: date(2, 28), from: start, calendar: calendar))
    }

    @Test func yearlyAndEveryNDays() {
        let yearly = RepeatRule(unit: .year)
        #expect(yearly.occurs(on: LocalDate(year: 2027, month: 10, day: 1), from: thursday, calendar: calendar))
        let everyThird = RepeatRule(interval: 3, unit: .day)
        #expect(everyThird.occurs(on: date(10, 4), from: thursday, calendar: calendar))
        #expect(!everyThird.occurs(on: date(10, 5), from: thursday, calendar: calendar))
    }

    @Test func nothingLandsBeforeTheStartOrAfterTheEnd() {
        let rule = RepeatRule(unit: .day, endsOn: date(10, 3))
        #expect(!rule.occurs(on: date(9, 30), from: thursday, calendar: calendar))
        #expect(rule.occurs(on: date(10, 3), from: thursday, calendar: calendar))
        #expect(!rule.occurs(on: date(10, 4), from: thursday, calendar: calendar))
    }

    @Test func kindsMatchTheRepeatMenu() {
        #expect(RepeatRule.everyDay.kind == .everyDay)
        #expect(RepeatRule.everyWeekday.kind == .everyWeekday)
        #expect(RepeatRule.weekly(on: 4).kind == .weekly)
        #expect(RepeatRule.monthly.kind == .monthly)
        #expect(RepeatRule(interval: 2, unit: .week).kind == .custom)
        #expect(RepeatRule(unit: .week, weekdays: [2, 4]).kind == .custom)
        #expect(RepeatRule(unit: .day, endsOn: date(10, 31)).kind == .custom)
    }

    @Test func summariesReadLikeTheCanvas() {
        #expect(RepeatRule.everyDay.summary(from: thursday, calendar: calendar) == "Every day")
        #expect(RepeatRule.everyWeekday.summary(from: thursday, calendar: calendar) == "Every weekday")
        #expect(RepeatRule.weekly(on: 4).summary(from: thursday, calendar: calendar) == "Weekly on Thu")
        #expect(RepeatRule.monthly.summary(from: thursday, calendar: calendar) == "Monthly on the 1st")
        let custom = RepeatRule(interval: 2, unit: .week, weekdays: [4, 2])
        #expect(custom.summary(from: thursday, calendar: calendar) == "Every 2 weeks on Tue and Thu")
        #expect(custom.sentence(from: thursday, calendar: calendar) == "Every 2 weeks on Tue and Thu, no end date.")
    }

    @Test func ordinals() {
        #expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 31].map(RepeatRule.ordinal) == [
            "1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "21st", "22nd", "23rd", "31st",
        ])
    }

    // MARK: Children

    private func parent(_ rule: RepeatRule) -> TaskItem {
        TaskItem(
            id: "review", listID: "work", title: "Weekly review", bucket: .backlog, rank: 1, estimate: 2_700,
            scheduledMinute: 16 * 60, repeatRule: rule, repeatStart: date(9, 24),
            subtasks: [Subtask(id: "a", title: "Inbox zero", isDone: true)])
    }

    @Test func childrenAreScheduledCopiesWithFixedIDs() throws {
        let week = WeekRange(containing: date(9, 30), calendar: calendar)
        let children = Recurrence.children(of: parent(.weekly(on: 5)), in: week, calendar: calendar)
        #expect(children.count == 1)
        let child = try #require(children.first)
        #expect(child.id == "review@2026-10-02")
        #expect(child.scheduledDate == date(10, 2))
        #expect(child.scheduledMinute == 16 * 60)
        #expect(child.repeatParentID == "review")
        #expect(!child.isRecurringParent)
        #expect(child.subtasks.map(\.isDone) == [false])
    }

    @Test func expandingTwiceNeverDuplicates() {
        let week = WeekRange(containing: date(9, 30), calendar: calendar)
        let once = Recurrence.expanding([parent(.everyWeekday)], in: week, calendar: calendar)
        let twice = Recurrence.expanding(once, in: week, calendar: calendar)
        #expect(once.count == 6)
        #expect(twice.count == once.count)
    }

    @Test func dismissedChildrenStayGone() {
        let week = WeekRange(containing: date(9, 30), calendar: calendar)
        let tasks = Recurrence.expanding(
            [parent(.everyDay)], in: week, dismissed: ["review@2026-10-01"], calendar: calendar)
        #expect(!tasks.contains { $0.id == "review@2026-10-01" })
        #expect(tasks.count == 7)
    }

    @Test func replacingKeepsFinishedChildren() {
        let week = WeekRange(containing: date(9, 30), calendar: calendar)
        var tasks = Recurrence.expanding([parent(.everyWeekday)], in: week, calendar: calendar)
        if let index = tasks.firstIndex(where: { $0.id == "review@2026-09-28" }) {
            tasks[index].completedAt = Date(timeIntervalSince1970: 0)
        }
        let kept = Recurrence.removingUnfinishedChildren(of: "review", from: tasks)
        #expect(kept.map(\.id) == ["review", "review@2026-09-28"])
    }
}
