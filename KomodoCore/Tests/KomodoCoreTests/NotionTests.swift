import Foundation
import Testing

@testable import KomodoCore

struct NotionTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    /// A data source's properties as Notion's reference documents them.
    let schemaJSON = """
        {"object": "data_source", "id": "ds1", "title": [{"plain_text": "Launch plan"}], "properties": {
          "Name": {"id": "title", "name": "Name", "type": "title", "title": {}},
          "When": {"id": "a1", "name": "When", "type": "date", "date": {}},
          "Stage": {"id": "a2", "name": "Stage", "type": "status", "status": {
            "options": [
              {"id": "o1", "name": "Not started", "color": "default"},
              {"id": "o2", "name": "Drafting", "color": "blue"},
              {"id": "o3", "name": "Shipped", "color": "green"}
            ],
            "groups": [
              {"id": "g1", "name": "To-do", "option_ids": ["o1"]},
              {"id": "g2", "name": "In progress", "option_ids": ["o2"]},
              {"id": "g3", "name": "Complete", "option_ids": ["o3"]}
            ]}},
          "Owner": {"id": "a3", "name": "Owner", "type": "people", "people": {}},
          "Reviewed": {"id": "a4", "name": "Reviewed", "type": "checkbox", "checkbox": {}},
          "Proofread": {"id": "a5", "name": "Proofread", "type": "checkbox", "checkbox": {}}
        }}
        """

    let pageJSON = """
        {"object": "page", "id": "p1", "url": "https://www.notion.so/Write-the-post-p1",
         "last_edited_time": "2026-10-01T09:30:00.000Z", "in_trash": false, "properties": {
          "Name": {"id": "title", "type": "title", "title": [{"plain_text": "Write the "}, {"plain_text": "post"}]},
          "When": {"id": "a1", "type": "date", "date": {"start": "2026-10-02", "end": "2026-10-05T15:00:00.000+00:00"}},
          "Stage": {"id": "a2", "type": "status", "status": {"id": "o2", "name": "Drafting"}},
          "Owner": {"id": "a3", "type": "people", "people": [{"object": "user", "id": "u1"}]},
          "Reviewed": {"id": "a4", "type": "checkbox", "checkbox": true},
          "Proofread": {"id": "a5", "type": "checkbox", "checkbox": false}
        }}
        """

    func decoded() throws -> (schema: Notion.Schema, page: Notion.Page, name: String) {
        let source = try JSONDecoder().decode(Notion.DataSource.self, from: Data(schemaJSON.utf8))
        let page = try JSONDecoder().decode(Notion.Page.self, from: Data(pageJSON.utf8))
        return (Notion.Schema(source.properties), page, source.name)
    }

    @Test func theSchemaFindsEachPropertyAndTheStatusGroups() throws {
        let (schema, _, name) = try decoded()
        #expect(name == "Launch plan")
        #expect(schema.title == "Name" && schema.date == "When" && schema.status == "Stage" && schema.people == "Owner")
        #expect(schema.checkboxes == ["Proofread", "Reviewed"])
        #expect(schema.statuses.map(\.kind) == [.todo, .active, .done])
    }

    @Test func aPageBecomesAnItemWithCheckboxesAsSubtasks() throws {
        let (schema, page, _) = try decoded()
        var connection = ProviderConnection()
        connection.statuses = schema.statuses
        let due = ExternalItem(page, schema: schema, ownerID: "u2", connection: connection, calendar: calendar)
        #expect(due.title == "Write the post" && due.bucket == .today && !due.isMine)
        #expect(due.date == LocalDate(year: 2026, month: 10, day: 5) && due.minute == 15 * 60 && due.dueDate == nil)
        #expect(due.subtasks?.map(\.title) == ["Proofread", "Reviewed"])
        #expect(due.subtasks?.map(\.isDone) == [false, true])
        connection.dateMapping = .start
        let start = ExternalItem(page, schema: schema, ownerID: "u1", connection: connection, calendar: calendar)
        #expect(start.date == LocalDate(year: 2026, month: 10, day: 2) && start.minute == nil && start.isMine)
        #expect(start.dueDate == LocalDate(year: 2026, month: 10, day: 5))
    }

    @Test func aPushWritesTheChangedProperties() throws {
        let (schema, _, _) = try decoded()
        var connection = ProviderConnection()
        connection.statuses = schema.statuses
        var task = TaskItem(id: "t", listID: "work", title: "Post", bucket: .today, rank: 1)
        task.scheduledDate = LocalDate(year: 2026, month: 10, day: 2)
        task.subtasks = [Subtask(id: "s", title: "Reviewed", isDone: true), Subtask(id: "x", title: "Mine only")]
        task.completedAt = .now
        let properties = Notion.properties(
            of: task, [.date, .done, .subtasks], schema: schema, connection: connection, calendar: calendar)
        #expect(properties["When"] == .object(["date": .object(["start": .string("2026-10-02")])]))
        #expect(properties["Stage"] == .object(["status": .object(["name": .string("Shipped")])]))
        #expect(properties["Reviewed"] == .object(["checkbox": .bool(true)]) && properties["Mine only"] == nil)
        task.scheduledDate = nil
        #expect(
            Notion.properties(of: task, [.date], schema: schema, connection: connection, calendar: calendar)["When"]
                == .object(["date": .null]))
    }
}
