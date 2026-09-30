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

    @Test func productivityFindsTheBestHourWeekdayAndMonth() {
        let tasks = [
            task("a", estimate: 3600, done: at(day(22), 11), sessions: [(at(day(22), 10), at(day(22), 11))]),
            task("b", estimate: 3600, done: at(day(22), 12), sessions: [(at(day(22), 11), at(day(22), 12, 30))]),
            task("c", done: at(day(24), 11), sessions: [(at(day(24), 10, 30), at(day(24), 11))]),
            task(
                "august",
                sessions: [
                    (at(LocalDate(year: 2026, month: 8, day: 3), 9), at(LocalDate(year: 2026, month: 8, day: 3), 10))
                ]),
        ]
        let productivity = Productivity(
            ReportData(tasks: tasks, breaks: [], listID: nil, now: now, calendar: calendar), range: week)
        #expect(productivity.bestHour == 10)
        #expect(productivity.hours[10] == 5400)
        #expect(productivity.weekdays.map(\.weekday) == [2, 3, 4, 5, 6, 7, 1])
        #expect(productivity.bestWeekday?.weekday == 3)
        #expect(productivity.bestWeekday?.tasksDone == 2)
        #expect(productivity.bestWeekday?.onEstimate == 0.5)
        #expect(productivity.weekdays.last?.isAhead == true)
        #expect(productivity.months.count == 9)
        #expect(productivity.bestMonth == 9)
    }

    @Test func todayIsComparedWithTheSameWeekdayLastWeek() {
        let range = ReportRange(.today, today: today, calendar: calendar)
        #expect(range.compared(to: .today, calendar: calendar) == ReportRange(first: day(19), last: day(19)))
        #expect(week.compared(to: .week, calendar: calendar).first == day(14))
    }

    @Test func punctualitySortsByOverrunAndTracksEightWeeks() {
        let tasks = [
            task("early", estimate: 3600, done: at(day(22), 11), sessions: [(at(day(22), 10), at(day(22), 10, 40))]),
            task("late", estimate: 1800, done: at(day(23), 11), sessions: [(at(day(23), 10), at(day(23), 11))]),
            task("on time", estimate: 3600, done: at(day(24), 11), sessions: [(at(day(24), 10), at(day(24), 11, 3))]),
            task("no estimate", done: at(day(24), 12), sessions: [(at(day(24), 11), at(day(24), 12))]),
            task("earlier", estimate: 600, done: at(day(8), 11), sessions: [(at(day(8), 10), at(day(8), 10, 30))]),
        ]
        let punctuality = Punctuality(
            ReportData(tasks: tasks, breaks: [], listID: nil, now: now, calendar: calendar), range: week)
        #expect(punctuality.summary.early == 1)
        #expect(punctuality.summary.onTime == 1)
        #expect(punctuality.summary.late == 1)
        #expect(punctuality.rows.map(\.taskID) == ["late", "on time", "early"])
        #expect(punctuality.rows.first?.delta == 1800)
        #expect(punctuality.weeks.count == 8)
        #expect(punctuality.weeks.last?.start == day(21))
        #expect(punctuality.weeks.last?.accuracy == 2.0 / 3)
        #expect(punctuality.weeks[5].accuracy == 0)
        #expect(punctuality.weeks[6].accuracy == nil)
    }

    @Test func timeSpentGroupsByListMostFirst() {
        let tasks = [
            task("brief", sessions: [(at(day(22), 9), at(day(22), 11))]),
            task("review", sessions: [(at(day(23), 9), at(day(23), 10))]),
            task("spec", list: "side", sessions: [(at(day(22), 12), at(day(22), 16))]),
            task("idle", list: "personal"),
        ]
        let spent = TimeSpent(
            ReportData(tasks: tasks, breaks: [], listID: nil, now: now, calendar: calendar), range: week)
        #expect(spent.lists.map(\.listID) == ["side", "work"])
        #expect(spent.lists[1].tasks.map(\.id) == ["brief", "review"])
        #expect(spent.total == 7 * 3600)
        #expect(spent.taskCount == 3)
        #expect(spent.share(of: spent.lists[0].time) == 4.0 / 7)
    }

    @Test func sessionLogListsNewestDayFirstWithNumbersAndBreaks() {
        let tasks = [
            task("brief", sessions: [(at(day(22), 9), at(day(22), 10)), (at(day(24), 9), at(day(24), 9, 30))]),
            task("live", sessions: [(at(today, 14), nil)]),
        ]
        let breaks = [
            BreakSession(id: "b1", start: at(day(24), 9, 30), end: at(day(24), 9, 35), taskID: "brief"),
            BreakSession(id: "b2", start: at(today, 14, 10), end: at(today, 14, 20), taskID: "live"),
        ]
        let data = ReportData(tasks: tasks, breaks: breaks, listID: nil, now: now, calendar: calendar)
        let log = SessionLog(data, range: week)
        #expect(log.days.map(\.date) == [today, day(24), day(22)])
        #expect(log.days[1].entries.map(\.id) == ["brief#2", "break:b1"])
        #expect(log.days[1].work == 1800)
        #expect(log.days[1].breaks == 300)
        // The running break counts up to now and shows no end.
        #expect(log.days[0].breaks == 240)
        #expect(log.days[0].entries.last?.end == nil)
        #expect(log.entryCount == 5)
        #expect(log.taskCount == 2)
        #expect(SessionLog(data, range: week, includesBreaks: false).entryCount == 3)
    }

    @Test func sessionLogExportsCSVOldestFirst() {
        let tasks = [task("Brief, final", sessions: [(at(day(22), 9), at(day(22), 9, 45))])]
        let breaks = [BreakSession(id: "b", start: at(day(23), 10), end: at(day(23), 10, 5))]
        let log = SessionLog(
            ReportData(tasks: tasks, breaks: breaks, listID: nil, now: now, calendar: calendar), range: week)
        let csv = log.csv(listNames: ["work": "Work"], now: now, calendar: calendar)
        #expect(
            csv == "type,task,list,session,started_at,ended_at,minutes\r\n"
                + "work,\"Brief, final\",Work,1,2026-09-22 09:00,2026-09-22 09:45,45.0\r\n"
                + "break,,,,2026-09-23 10:00,2026-09-23 10:05,5.0\r\n")
    }
}
