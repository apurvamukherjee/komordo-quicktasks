import Foundation
import Testing

@testable import KomodoCore

struct BoardLayoutTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return calendar
    }()

    // Saturday, Sep 26 2026, the date on the Main artboard.
    private let today = LocalDate(year: 2026, month: 9, day: 26)
    private var week: WeekRange { WeekRange(containing: today, calendar: calendar) }

    private func task(
        _ id: String, bucket: Bucket = .backlog, rank: Double = 0, date: LocalDate? = nil, minute: Int? = nil,
        estimate: TimeInterval? = nil, completedAt: Date? = nil, sessions: [WorkSession] = []
    ) -> TaskItem {
        TaskItem(
            id: id, listID: "work", title: id, bucket: bucket, rank: rank, estimate: estimate, scheduledDate: date,
            scheduledMinute: minute, completedAt: completedAt, sessions: sessions)
    }

    @Test func weekStartsOnMonday() {
        #expect(week.start == LocalDate(year: 2026, month: 9, day: 21))
        #expect(week.end == LocalDate(year: 2026, month: 9, day: 27))
        #expect(week.days.count == 7)
    }

    @Test func scheduledTasksTakeTheirColumnFromTheDate() {
        #expect(task("overdue", date: LocalDate(year: 2026, month: 9, day: 20)).column(in: week) == .today)
        #expect(task("today", date: today).column(in: week) == .today)
        #expect(
            task("sunday", bucket: .today, date: LocalDate(year: 2026, month: 9, day: 27)).column(in: week) == .week)
        #expect(
            task("later", bucket: .today, date: LocalDate(year: 2026, month: 10, day: 10)).column(in: week) == .backlog)
        #expect(task("parked", bucket: .week).column(in: week) == .week)
    }

    @Test func todaySplitsIntoQueueScheduledAndDone() {
        let noon = today.startOfDay(in: calendar).addingTimeInterval(12 * 3600)
        let tasks = [
            task("second", bucket: .today, rank: 2),
            task("first", bucket: .today, rank: 1),
            task("meeting", date: today, minute: 15 * 60),
            task("standup", date: today, minute: 9 * 60),
            task("allDay", rank: 3, date: today),
            task("finished", bucket: .today, completedAt: noon),
            task("yesterday", bucket: .today, completedAt: noon.addingTimeInterval(-86_400)),
        ]
        let layout = BoardLayout(tasks: tasks, week: week, calendar: calendar)
        #expect(layout.upNext.map(\.id) == ["first", "second", "allDay"])
        #expect(layout.scheduledToday.map(\.id) == ["standup", "meeting"])
        #expect(layout.doneToday.map(\.id) == ["finished"])
    }

    @Test func timedTasksJoinTheQueueFirstOnceTheirTimePasses() {
        let now = today.startOfDay(in: calendar).addingTimeInterval(14 * 3600 + 14 * 60)
        let tasks = [
            task("queued", bucket: .today, rank: 1),
            task("review", date: today, minute: 15 * 60),
            task("lunch", date: today, minute: 13 * 60),
            task("standup", date: today, minute: 9 * 60),
            task("atTheMinute", date: today, minute: 14 * 60 + 14),
        ]
        let layout = BoardLayout(tasks: tasks, week: week, now: now, calendar: calendar)
        #expect(layout.upNext.map(\.id) == ["standup", "lunch", "atTheMinute", "queued"])
        #expect(layout.scheduledToday.map(\.id) == ["review"])
    }

    @Test func datedTasksSitBelowHandPlacedOnesInThisWeek() {
        let tasks = [
            task("sunday", date: LocalDate(year: 2026, month: 9, day: 27)),
            task("placed", bucket: .week, rank: 5),
        ]
        let layout = BoardLayout(tasks: tasks, week: week, calendar: calendar)
        #expect(layout.week.map(\.id) == ["placed", "sunday"])
    }

    @Test func filtersToOneList() {
        var other = task("other", bucket: .backlog)
        other.listID = "personal"
        let layout = BoardLayout(tasks: [task("mine"), other], listID: "work", week: week, calendar: calendar)
        #expect(layout.backlog.map(\.id) == ["mine"])
    }

    @Test func dayPlanProjectsStartsFromTheLiveTask() {
        let now = today.startOfDay(in: calendar).addingTimeInterval(14 * 3600 + 14 * 60)
        // 50:34 into a 1hr estimate leaves 9:26, so the next task starts at 2:23 PM, as on the artboard.
        let live = task(
            "live", bucket: .today, estimate: 3_600, sessions: [WorkSession(start: now.addingTimeInterval(-3_034))])
        let next = task(
            "next", bucket: .today, estimate: 5_400,
            sessions: [WorkSession(start: now, end: now.addingTimeInterval(1_800))])
        let after = task("after", bucket: .today, estimate: 9_000)
        let plan = DayPlan(
            now: now, live: live, queue: [next, after], scheduled: [], doneToday: [], allTasks: [live, next, after],
            today: today, calendar: calendar)

        let offsets = plan.startTimes.map { Int($0.timeIntervalSince(now)) }
        #expect(offsets == [566, 566 + 3_600])
        #expect(plan.estimateLeft == 566 + 3_600 + 9_000)
        #expect(plan.total == 3)
        #expect(plan.done == 0)
    }

    @Test func focusedCountsOnlyTodaysPartOfEachSession() {
        let midnight = today.startOfDay(in: calendar)
        let now = midnight.addingTimeInterval(10 * 3600)
        let overnight = task(
            "overnight",
            sessions: [WorkSession(start: midnight.addingTimeInterval(-1_800), end: midnight.addingTimeInterval(600))])
        let plan = DayPlan(
            now: now, live: nil, queue: [], scheduled: [], doneToday: [], allTasks: [overnight], today: today,
            calendar: calendar)
        #expect(plan.focused == 600)
    }

    @Test func theDaySpansFirstWorkToLastFinish() {
        let midnight = today.startOfDay(in: calendar)
        let overnight = task(
            "overnight", completedAt: midnight.addingTimeInterval(600),
            sessions: [WorkSession(start: midnight.addingTimeInterval(-1_800), end: midnight.addingTimeInterval(600))])
        let afternoon = task(
            "afternoon", completedAt: midnight.addingTimeInterval(17 * 3600),
            sessions: [
                WorkSession(start: midnight.addingTimeInterval(16 * 3600), end: midnight.addingTimeInterval(17 * 3600))
            ])
        let plan = DayPlan(
            now: midnight.addingTimeInterval(18 * 3600), live: nil, queue: [], scheduled: [],
            doneToday: [afternoon, overnight], allTasks: [afternoon, overnight], today: today, calendar: calendar)
        #expect(plan.firstStart == midnight)
        #expect(plan.lastFinish == midnight.addingTimeInterval(17 * 3600))
    }
}
