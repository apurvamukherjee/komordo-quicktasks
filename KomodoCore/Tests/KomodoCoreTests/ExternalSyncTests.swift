import Foundation
import Testing

@testable import KomodoCore

struct ExternalItemTests {
    private let day = LocalDate(year: 2026, month: 10, day: 2)

    @Test func aTaskAndItsItemAgreeWhenTheirSyncedFieldsMatch() {
        let item = ExternalItem(id: "1", title: "Write post", notes: nil, date: day, minute: 900, estimate: 2_700)
        let task = TaskItem(
            id: "t", listID: "work", title: "Write post", bucket: .backlog, rank: 3, estimate: 2_710, notes: "",
            scheduledDate: day, scheduledMinute: 900, sessions: [WorkSession(start: .now)])
        #expect(ExternalItem.snapshot(of: task) == item.snapshot)
    }

    @Test func anyEditToASyncedFieldChangesTheSnapshot() {
        let item = ExternalItem(id: "1", title: "Write post", date: day)
        var renamed = item
        renamed.title = "Write the post"
        var done = item
        done.isDone = true
        var moved = item
        moved.date = day.adding(days: 1, calendar: Calendar(identifier: .gregorian))
        #expect(Set([item, renamed, done, moved].map(\.snapshot)).count == 4)
    }
}
