import Foundation
import Testing

@testable import KomodoCore

/// Responses shaped like Todoist's API v1 sync endpoint documents them. They stand in for recorded ones until a
/// test token is available (HANDOFF §9).
enum TodoistFixtures {
    static let fullSync = """
        {
          "sync_token": "TnYUZEpuzf2FMA9qzyY3j4xky6dXiYejmSO85S5paZ_a9y1FI85mBbIWZGpW",
          "full_sync": true,
          "user": { "id": "2671355", "email": "apurva@example.com", "full_name": "Apurva" },
          "projects": [
            { "id": "6Jf8VQXxpwv56VQ7", "name": "Inbox", "inbox_project": true, "is_deleted": false,
              "is_archived": false },
            { "id": "6Jf8VQXxpwv56VQ8", "name": "Komodo launch", "is_deleted": false, "is_archived": false },
            { "id": "6Jf8VQXxpwv56VQ9", "name": "Old ideas", "is_deleted": false, "is_archived": true }
          ],
          "items": [
            { "id": "6X7rM8997g3RQmvh", "user_id": "2671355", "project_id": "6Jf8VQXxpwv56VQ8",
              "content": "Write the launch post", "description": "Draft in https://notes.example.com/launch",
              "due": { "date": "2026-10-02T15:00:00", "timezone": null, "string": "today at 3pm", "lang": "en",
                       "is_recurring": false },
              "deadline": { "date": "2026-10-09", "lang": "en" },
              "duration": { "amount": 45, "unit": "minute" },
              "priority": 1, "parent_id": null, "child_order": 1, "section_id": null, "checked": false,
              "is_deleted": false, "responsible_uid": null, "added_at": "2026-09-30T10:12:00.123456Z",
              "updated_at": "2026-10-01T09:30:00.000000Z", "completed_at": null },
            { "id": "6X7rfFVPjhvv84XG", "user_id": "2671355", "project_id": "6Jf8VQXxpwv56VQ8",
              "content": "Record the demo", "description": "", "due": null, "deadline": null, "duration": null,
              "priority": 4, "parent_id": null, "child_order": 2, "section_id": null, "checked": false,
              "is_deleted": false, "responsible_uid": "9988776", "added_at": "2026-09-30T10:13:00.000000Z",
              "updated_at": "2026-09-30T10:13:00.000000Z", "completed_at": null }
          ],
          "sync_status": {},
          "temp_id_mapping": {}
        }
        """

    static let commandResults = """
        {
          "sync_token": "VRyFHr0Qo3Hr--pzINyT6nax4vW7X2YG5RQlw3lB-6eYOPbSZVJepa62EVhO",
          "full_sync": false,
          "items": [],
          "sync_status": {
            "c4a1f6b0-0000-4000-8000-000000000001": "ok",
            "c4a1f6b0-0000-4000-8000-000000000002": { "error_code": 22, "error": "Item not found",
              "http_code": 404, "error_extra": {}, "error_tag": "ITEM_NOT_FOUND" }
          },
          "temp_id_mapping": { "komodo-task-1": "6X7rnpVGgr3gHJ9q" }
        }
        """

    static func decode(_ json: String) throws -> Todoist.SyncResponse {
        try JSONDecoder().decode(Todoist.SyncResponse.self, from: Data(json.utf8))
    }
}

struct TodoistTests {
    @Test func aFullSyncReadsItemsProjectsAndTheUser() throws {
        let response = try TodoistFixtures.decode(TodoistFixtures.fullSync)
        #expect(response.fullSync)
        #expect(response.user?.id == "2671355")
        #expect(response.projects.map(\.name) == ["Inbox", "Komodo launch", "Old ideas"])
        #expect(response.projects[2].isArchived)
        let post = try #require(response.items.first)
        #expect(post.content == "Write the launch post")
        #expect(post.due == Todoist.Due(date: "2026-10-02T15:00:00"))
        #expect(post.deadline == Todoist.Deadline(date: "2026-10-09"))
        #expect(post.duration == Todoist.Duration(amount: 45, unit: "minute"))
        #expect(response.items[1].responsibleUID == "9988776")
    }

    @Test func commandResultsReadOkFailuresAndNewIDs() throws {
        let response = try TodoistFixtures.decode(TodoistFixtures.commandResults)
        #expect(response.syncStatus["c4a1f6b0-0000-4000-8000-000000000001"] == .ok)
        #expect(response.syncStatus["c4a1f6b0-0000-4000-8000-000000000002"] == .failed("Item not found"))
        #expect(response.tempIDMapping == ["komodo-task-1": "6X7rnpVGgr3gHJ9q"])
        #expect(response.projects.isEmpty)
    }
}

struct TodoistItemTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata") ?? .gmt
        return calendar
    }

    @Test func wholeDaysFloatingTimesAndFixedTimesReadAsLocal() {
        let day = LocalDate(year: 2026, month: 10, day: 2)
        #expect(Todoist.Due(date: "2026-10-02").schedule(in: calendar)! == (day, nil))
        #expect(Todoist.Due(date: "2026-10-02T15:00:00").schedule(in: calendar)! == (day, 900))
        // 20:00 UTC is 01:30 the next morning in India.
        #expect(
            Todoist.Due(date: "2026-10-02T20:00:00.000000Z").schedule(in: calendar)!
                == (day.adding(days: 1, calendar: calendar), 90))
        #expect(Todoist.Due(date: "soon").schedule(in: calendar) == nil)
    }

    @Test func anItemBecomesAnExternalItem() throws {
        let response = try TodoistFixtures.decode(TodoistFixtures.fullSync)
        let post = ExternalItem(response.items[0], userID: "2671355", calendar: calendar)
        #expect(post.title == "Write the launch post")
        #expect(post.notes == "Draft in https://notes.example.com/launch")
        #expect(post.date == LocalDate(year: 2026, month: 10, day: 2))
        #expect(post.minute == 900)
        #expect(post.dueDate == LocalDate(year: 2026, month: 10, day: 9))
        #expect(post.estimate == 2_700)
        #expect(post.isMine)
        #expect(post.updatedAt == Date(timeIntervalSince1970: 1_790_847_000))
        #expect(post.url?.absoluteString == "https://app.todoist.com/app/task/6X7rM8997g3RQmvh")
        let demo = ExternalItem(response.items[1], userID: "2671355", calendar: calendar)
        #expect(!demo.isMine)
        #expect(demo.notes == nil && demo.date == nil && demo.estimate == nil)
    }
}
