import Foundation
import Testing

@testable import KomodoCore

struct CalendarImportTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    // Thursday 1 October 2026, 08:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_790_841_600)
    private var today: LocalDate { LocalDate(now, calendar: calendar) }
    private var week: WeekRange { WeekRange(containing: today, calendar: calendar) }

    private func at(_ days: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        now.addingTimeInterval(TimeInterval(days * 86_400 + (hour - 8) * 3_600 + minute * 60))
    }

    private func event(
        _ id: String, _ title: String, day: Int = 0, hour: Int = 15, minutes: Int = 30, accepted: Bool = true
    ) -> CalendarEvent {
        CalendarEvent(
            id: id, title: title, start: at(day, hour), end: at(day, hour, minutes),
            notes: "Join: https://meet.google.com/abc-defg-hij", calendarTitle: "Work", isAccepted: accepted)
    }

    private func sync(
        _ events: [CalendarEvent], board: [TaskItem] = [], known: Set<String> = [], acceptedOnly: Bool = false
    )
        -> [TaskItem]
    {
        CalendarImport.sync(
            events, board: board, known: known.union(board.map(\.id)), listID: "work", calendars: ["Work"],
            days: today...today.adding(days: 13, calendar: calendar), acceptedOnly: acceptedOnly, week: week,
            now: now, calendar: calendar)
    }

    @Test func eventsBecomeTasksPlacedByDate() throws {
        let tasks = sync([
            event("a", "Design review"), event("b", "Planning", day: 2, hour: 10, minutes: 60),
            CalendarEvent(
                id: "c", title: "Offsite", start: at(9, 0), end: at(10, 0), isAllDay: true, calendarTitle: "Work"),
        ])
        #expect(tasks.map(\.id) == ["calendar:a", "calendar:b", "calendar:c"])
        let review = tasks[0]
        #expect(review.column(in: week) == .today)
        #expect(review.scheduledMinute == 15 * 60)
        #expect(review.estimate == 1_800)
        #expect(review.source == .calendar)
        #expect(review.sourceTitle == "Work")
        #expect(review.sourceURL == URL(string: "https://meet.google.com/abc-defg-hij"))
        #expect(tasks[1].column(in: week) == .week)
        #expect(tasks[2].column(in: week) == .backlog)
        #expect(tasks[2].scheduledMinute == nil)
        #expect(tasks[2].estimate == nil)
    }

    @Test func aSecondSyncChangesNothing() {
        let first = sync([event("a", "Design review")])
        #expect(sync([event("a", "Design review")], board: first).isEmpty)
    }

    @Test func aMovedEventMovesItsTaskButKeepsTheNotes() throws {
        var task = try #require(sync([event("a", "Design review")]).first)
        task.notes = "Bring the mocks, Apurva"
        let moved = try #require(sync([event("a", "Design review v2", day: 1, hour: 11)], board: [task]).first)
        #expect(moved.title == "Design review v2")
        #expect(moved.scheduledDate == today.adding(days: 1, calendar: calendar))
        #expect(moved.scheduledMinute == 11 * 60)
        #expect(moved.notes == "Bring the mocks, Apurva")
    }

    @Test func deletedOrDoneTasksStayAsTheyAre() throws {
        #expect(sync([event("a", "Design review")], known: ["calendar:a"]).isEmpty)
        var done = try #require(sync([event("a", "Design review")]).first)
        done.completedAt = now
        #expect(sync([event("a", "Renamed", day: 1)], board: [done]).isEmpty)
    }

    @Test func aGoneEventOnlyUnlinksItsTask() throws {
        var task = try #require(sync([event("a", "Design review")]).first)
        task.sessions = [WorkSession(start: now, end: now.addingTimeInterval(600))]
        let unlinked = try #require(sync([], board: [task]).first)
        #expect(unlinked.id == task.id)
        #expect(unlinked.source == nil)
        #expect(unlinked.sourceURL == nil)
        #expect(unlinked.sessions == task.sessions)

        // A calendar that wasn't read this time leaves its tasks linked.
        var other = task
        other.sourceTitle = "Family"
        #expect(sync([], board: [other]).isEmpty)
    }

    @Test func acceptedOnlySkipsInvitationsNotYetAccepted() {
        let tasks = sync([event("a", "Design review"), event("b", "Maybe lunch", accepted: false)], acceptedOnly: true)
        #expect(tasks.map(\.id) == ["calendar:a"])
    }

    @Test func meetingLinksComeFromTheEventFirst() {
        var call = event("a", "Call")
        #expect(call.meetingLink?.host() == "meet.google.com")
        call.url = URL(string: "https://zoom.us/j/123")
        #expect(call.meetingLink?.host() == "zoom.us")
        call.url = nil
        call.notes = "Agenda at https://docs.example.com"
        #expect(call.meetingLink == nil)
    }
}
