import Foundation
import Testing

@testable import KomodoCore

struct ReportTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return calendar
    }()

    // Saturday, Sep 26 2026, 2:14 PM, as on the artboards.
    let today = LocalDate(year: 2026, month: 9, day: 26)
    var now: Date { at(today, 14, 14) }
    var week: ReportRange { ReportRange(.week, today: today, calendar: calendar) }

    func at(_ day: LocalDate, _ hour: Int, _ minute: Int = 0) -> Date {
        day.startOfDay(in: calendar).addingTimeInterval(TimeInterval(hour * 3600 + minute * 60))
    }

    func day(_ number: Int) -> LocalDate { LocalDate(year: 2026, month: 9, day: number) }

    func task(
        _ id: String, list: String = "work", estimate: TimeInterval? = nil, done: Date? = nil,
        sessions: [(Date, Date?)] = []
    ) -> TaskItem {
        TaskItem(
            id: id, listID: list, title: id, bucket: .today, rank: 0, estimate: estimate, completedAt: done,
            sessions: sessions.map { WorkSession(start: $0.0, end: $0.1) })
    }

    @Test func overviewCountsWorkDaysTasksHoursAndBreaks() {
        let tasks = [
            task("brief", done: at(day(22), 11), sessions: [(at(day(22), 9), at(day(22), 11))]),
            task("spec", list: "side", done: at(day(24), 12), sessions: [(at(day(24), 10), at(day(24), 11))]),
            // Runs across midnight into Friday.
            task("late", sessions: [(at(day(24), 23), at(day(25), 1))]),
            task("live", sessions: [(at(today, 14), nil)]),
            task("last week", done: at(day(18), 10), sessions: [(at(day(18), 9), at(day(18), 10))]),
        ]
        let breaks = [BreakSession(id: "b", start: at(day(22), 11), end: at(day(22), 11, 10), taskID: "brief")]
        let overview = ReportOverview(
            ReportData(tasks: tasks, breaks: breaks, listID: nil, now: now, calendar: calendar), range: week)
        #expect(overview.days.count == 7)
        #expect(overview.workDays == 4)
        #expect(overview.tasksDone == 2)
        #expect(overview.hours == (2 + 1 + 2) * 3600 + 14 * 60)
        #expect(overview.days[1].breaks == 600)
        #expect(overview.days[1].session == 2 * 3600 + 600)
        #expect(overview.averagePerTask == overview.hours / 2)
    }

    @Test func aListFilterDropsOtherTasksAndTheirBreaks() {
        let tasks = [
            task("brief", sessions: [(at(day(22), 9), at(day(22), 10))]),
            task("spec", list: "side", sessions: [(at(day(22), 10), at(day(22), 11))]),
        ]
        let breaks = [
            BreakSession(id: "a", start: at(day(22), 10), end: at(day(22), 10, 5), taskID: "brief"),
            BreakSession(id: "b", start: at(day(22), 11), end: at(day(22), 11, 5), taskID: "spec"),
            BreakSession(id: "c", start: at(day(22), 12), end: at(day(22), 12, 5)),
        ]
        let data = ReportData(tasks: tasks, breaks: breaks, listID: "side", now: now, calendar: calendar)
        #expect(data.tasks.map(\.id) == ["spec"])
        #expect(data.breaks.map(\.id) == ["b"])
    }
}
