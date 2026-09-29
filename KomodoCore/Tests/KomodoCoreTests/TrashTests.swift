import Foundation
import Testing

@testable import KomodoCore

struct TrashTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return calendar
    }()

    private func day(_ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour)) ?? .distantPast
    }

    @Test(
        arguments: [
            (9, 26, 30), (9, 24, 28), (8, 30, 3), (8, 28, 1), (8, 27, 0),
        ] as [(Int, Int, Int)])
    func countsDaysLeftTheWayTheCanvasDoes(month: Int, day deleted: Int, left: Int) {
        let now = day(9, 26, hour: 11)
        #expect(Trash.daysLeft(deletedAt: day(month, deleted), now: now, calendar: calendar) == left)
        #expect(Trash.isExpired(deletedAt: day(month, deleted), now: now, calendar: calendar) == (left <= 0))
    }

    @Test func trashAndArchiveLoadApartFromTheBoard() throws {
        let database = try AppDatabase.inMemory()
        var change = BoardChange.lists(from: [], to: [TaskList(id: "work", name: "Work", color: "lime")])
        let open = TaskItem(id: "open", listID: "work", title: "Open", bucket: .today, rank: 0)
        var trashed = open
        trashed.id = "trashed"
        trashed.deletedAt = day(9, 20)
        var archived = open
        archived.id = "archived"
        archived.archivedAt = day(9, 21)
        change.savedTasks = [open, trashed, archived]
        try database.apply(change)
        let board = try database.load()
        #expect(board.tasks == [open])
        #expect(board.trash == [trashed])
        #expect(board.archived == [archived])
    }
}
