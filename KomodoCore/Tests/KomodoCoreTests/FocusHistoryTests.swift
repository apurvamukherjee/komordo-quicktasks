import Foundation
import Testing

@testable import KomodoCore

struct FocusHistoryTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()
    private let today = LocalDate(year: 2026, month: 9, day: 26)

    private func worked(daysAgo: Int, minutes: Double) -> TaskItem {
        let start = today.adding(days: -daysAgo, calendar: calendar).startOfDay(in: calendar).addingTimeInterval(
            9 * 3600)
        return TaskItem(
            id: "\(daysAgo)", listID: "work", title: "t", bucket: .today, rank: 0,
            sessions: [WorkSession(start: start, end: start.addingTimeInterval(minutes * 60))])
    }

    @Test func sumsEachDay() {
        let now = today.startOfDay(in: calendar).addingTimeInterval(12 * 3600)
        let days = [today.adding(days: -1, calendar: calendar), today]
        let totals = FocusHistory.daily(
            [worked(daysAgo: 1, minutes: 30), worked(daysAgo: 0, minutes: 90)], days: days,
            now: now, calendar: calendar)
        #expect(totals == [1_800, 5_400])
    }

    private func done(daysAgo: Int) -> TaskItem {
        let at = today.adding(days: -daysAgo, calendar: calendar).startOfDay(in: calendar).addingTimeInterval(10 * 3600)
        return TaskItem(id: "done-\(daysAgo)", listID: "work", title: "t", bucket: .today, rank: 0, completedAt: at)
    }

    @Test func streakCountsBackFromToday() {
        let tasks = [0, 1, 2, 4].map { done(daysAgo: $0) }
        #expect(FocusHistory.streak(tasks, today: today, calendar: calendar) == 3)
    }

    @Test func anEmptyMorningKeepsYesterdaysStreak() {
        let tasks = [1, 2].map { done(daysAgo: $0) }
        #expect(FocusHistory.streak(tasks, today: today, calendar: calendar) == 2)
    }

    @Test func focusWithoutATaskDoneDoesntCount() {
        let tasks = [done(daysAgo: 0), worked(daysAgo: 1, minutes: 90), done(daysAgo: 2)]
        #expect(FocusHistory.streak(tasks, today: today, calendar: calendar) == 1)
    }
}
