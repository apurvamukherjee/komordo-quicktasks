import Foundation
import Testing

@testable import KomodoCore

struct ClickUpTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private let day = LocalDate(year: 2026, month: 10, day: 2)

    /// A list's tasks as ClickUp's reference documents them; IDs and times come as strings.
    let response = """
        {"tasks": [
          {"id": "86a1", "name": "Write the release notes", "text_content": "Changelog first",
           "status": {"status": "in progress", "type": "custom", "color": "#4194f6"},
           "date_updated": "1790845200000", "start_date": "1790899200000", "due_date": "1791122400000",
           "time_estimate": 2700000, "assignees": [{"id": 183, "username": "Apurva"}],
           "url": "https://app.clickup.com/t/86a1", "archived": false},
          {"id": "86a2", "name": "Archive old screenshots", "text_content": "",
           "status": {"status": "complete", "type": "closed"}, "date_updated": "1790845300000",
           "start_date": null, "due_date": null, "time_estimate": null, "assignees": [{"id": 9}],
           "url": "https://app.clickup.com/t/86a2", "archived": false}
        ], "last_page": true}
        """

    var connection: ProviderConnection {
        var connection = ProviderConnection()
        connection.statuses = ClickUp.statuses([
            ClickUp.Status(status: "to do", type: "open"), ClickUp.Status(status: "in progress", type: "custom"),
            ClickUp.Status(status: "complete", type: "closed"),
        ])
        return connection
    }

    @Test func aTaskBecomesAnItemWithItsEstimateAndStatus() throws {
        let page = try JSONDecoder().decode(ClickUp.TaskPage.self, from: Data(response.utf8))
        #expect(page.lastPage == true)
        let items = page.tasks.map { ExternalItem($0, userID: "183", connection: connection, calendar: calendar) }
        // Due 4 October 14:00 UTC, scheduled by the due date.
        #expect(items[0].date == LocalDate(year: 2026, month: 10, day: 4) && items[0].minute == 14 * 60)
        #expect(items[0].estimate == 2_700 && items[0].bucket == .today && items[0].isMine)
        #expect(items[0].updatedAt == Date(timeIntervalSince1970: 1_790_845_200))
        #expect(items[1].isDone && items[1].notes == nil && !items[1].isMine && items[1].estimate == nil)
        var start = connection
        start.dateMapping = .start
        let started = ExternalItem(page.tasks[0], userID: "183", connection: start, calendar: calendar)
        #expect(started.date == day && started.minute == nil)
        #expect(started.dueDate == LocalDate(year: 2026, month: 10, day: 4))
    }

    @Test func aPushSendsDatesInMillisecondsAndTheMappedStatus() {
        var task = TaskItem(id: "t", listID: "work", title: "Notes", bucket: .today, rank: 1, estimate: 1_800)
        task.scheduledDate = day
        task.scheduledMinute = 9 * 60
        let body = ClickUp.fields(
            of: task, [.date, .minute, .estimate, .column], connection: connection, calendar: calendar)
        #expect(body["due_date"] == .int(1_790_899_200_000 + 9 * 3_600_000) && body["due_date_time"] == .bool(true))
        #expect(body["time_estimate"] == .int(1_800_000) && body["status"] == .string("in progress"))
        task.completedAt = .now
        #expect(
            ClickUp.fields(of: task, [.done], connection: connection, calendar: calendar)["status"]
                == .string("complete"))
        task.notes = ""
        #expect(
            ClickUp.fields(of: task, [.notes], connection: connection, calendar: calendar) == [
                "description": .string(" ")
            ])
    }

    @Test func aChangedTaskReplacesItsOpenCopy() {
        let open = ClickUp.Status(status: "to do", type: "open")
        let tasks = [
            ClickUp.Task(id: "1", name: "A", status: open, dateUpdated: "100"),
            ClickUp.Task(id: "2", name: "B", status: open, dateUpdated: "200"),
        ]
        let closed = ClickUp.Task(
            id: "1", name: "A", status: ClickUp.Status(status: "complete", type: "closed"), dateUpdated: "300")
        let merged = ClickUp.merge(open: tasks, changed: [closed], cursor: "50")
        #expect(merged.tasks.map(\.status.type) == ["open", "closed"] && merged.cursor == "300")
        #expect(ClickUp.tasksQuery(since: "300", page: 1).contains(URLQueryItem(name: "include_closed", value: "true")))
    }
}
