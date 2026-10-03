import Foundation
import Testing

@testable import KomodoCore

struct AsanaTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .gmt
        return calendar
    }

    private let day = LocalDate(year: 2026, month: 10, day: 2)

    /// A project's tasks as Asana's reference documents them.
    let response = """
        {"data": [
          {"gid": "1201", "name": "Draft the brief", "notes": "For Apurva", "due_on": "2026-10-05",
           "due_at": null, "start_on": "2026-10-02", "start_at": null, "completed": false,
           "modified_at": "2026-10-01T09:30:00.000Z", "assignee": {"gid": "77", "resource_type": "user"},
           "permalink_url": "https://app.asana.com/0/42/1201", "num_subtasks": 2},
          {"gid": "1202", "name": "Call the printer", "notes": "", "due_on": "2026-10-02",
           "due_at": "2026-10-02T09:30:00.000Z", "start_on": null, "start_at": null, "completed": true,
           "modified_at": "2026-10-01T10:00:00.000Z", "assignee": null, "permalink_url": null, "num_subtasks": 0}
        ],
        "next_page": {"offset": "eyJ0", "path": "/tasks?offset=eyJ0", "uri": "https://app.asana.com/api/1.0/tasks?offset=eyJ0"}}
        """

    @Test func theMappedDateSchedulesATask() throws {
        let page = try JSONDecoder().decode(Asana.Envelope<[Asana.Task]>.self, from: Data(response.utf8))
        #expect(page.nextPage?.offset == "eyJ0")
        let due = page.data.map { ExternalItem($0, subtasks: nil, userID: "77", mapping: .due, calendar: calendar) }
        #expect(due[0].date == LocalDate(year: 2026, month: 10, day: 5) && due[0].dueDate == nil)
        #expect(due[1].date == day && due[1].minute == 15 * 60 && due[1].isDone)
        #expect(due[0].notes == "For Apurva" && due[1].notes == nil && due[0].isMine && due[1].isMine)
        let start = ExternalItem(page.data[0], subtasks: nil, userID: "8", mapping: .start, calendar: calendar)
        #expect(start.date == day && start.dueDate == LocalDate(year: 2026, month: 10, day: 5) && !start.isMine)
        #expect(start.url?.absoluteString == "https://app.asana.com/0/42/1201")
    }

    @Test func subtasksComeAlongWhenRead() {
        let item = ExternalItem(
            Asana.Task(gid: "1", name: "Ship"), subtasks: [Asana.Task(gid: "2", name: "Proof", completed: true)],
            userID: nil, mapping: .due, calendar: calendar)
        #expect(item.subtasks == [Subtask(id: "2", title: "Proof", isDone: true)])
    }

    @Test func aPushSendsOnlyTheChangedFields() {
        var task = TaskItem(id: "t", listID: "work", title: "Draft", bucket: .backlog, rank: 1)
        task.scheduledDate = day
        task.scheduledMinute = 15 * 60
        let timed = Asana.fields(of: task, [.date, .minute], mapping: .due, calendar: calendar)
        #expect(timed == ["due_at": .string("2026-10-02T09:30:00Z")])
        task.scheduledMinute = nil
        let started = Asana.fields(of: task, [.date, .title], mapping: .start, calendar: calendar)
        #expect(
            started == ["name": .string("Draft"), "start_on": .string("2026-10-02"), "due_on": .string("2026-10-02")])
        task.scheduledDate = nil
        #expect(Asana.fields(of: task, [.date], mapping: .due, calendar: calendar) == ["due_on": .null])
    }

    @Test func subtasksMatchByIDThenTitle() {
        let local = [
            Subtask(id: "2", title: "Proof the copy", isDone: true), Subtask(id: "x", title: "Print"),
            Subtask(id: "y", title: "Post"),
        ]
        let remote = [Asana.Task(gid: "2", name: "Proof"), Asana.Task(gid: "3", name: "Print")]
        let changes = Asana.subtaskChanges(local: local, remote: remote)
        #expect(changes.map(\.gid) == ["2", nil])
        #expect(changes[0].data == ["name": .string("Proof the copy"), "completed": .bool(true)])
        #expect(changes[1].data == ["name": .string("Post"), "completed": .bool(false)])
    }

    @Test func aPageAsksForOpenAndRecentlyFinishedTasks() {
        let query = Asana.tasksQuery(projectID: "42", completedSince: nil, offset: nil)
        #expect(query.first { $0.name == "completed_since" }?.value == "now")
        let next = Asana.tasksQuery(
            projectID: "42", completedSince: Date(timeIntervalSince1970: 1_790_841_600), offset: "eyJ0")
        #expect(next.first { $0.name == "completed_since" }?.value == "2026-10-01T08:00:00Z")
        #expect(next.last?.value == "eyJ0")
    }
}
