import Foundation
import Testing

@testable import KomodoCore

struct StorageTests {
    private let work = TaskList(id: "work", name: "Work", color: "lime")
    private let personal = TaskList(id: "personal", name: "Personal", color: "teal")
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    /// A task with every field set, so a round trip proves each column.
    private var rich: TaskItem {
        TaskItem(
            id: "weekly", listID: "work", title: "Weekly review", bucket: .week, rank: 2.5, estimate: 2_700,
            notes: "See https://example.com", notesRTF: Data([1, 2, 3]), opensLinks: false,
            scheduledDate: LocalDate(year: 2026, month: 10, day: 2), scheduledMinute: 870,
            dueDate: LocalDate(year: 2026, month: 10, day: 9),
            repeatRule: RepeatRule(
                interval: 2, unit: .week, weekdays: [2, 4], endsOn: LocalDate(year: 2026, month: 12, day: 31)),
            repeatStart: LocalDate(year: 2026, month: 9, day: 28), repeatParentID: nil, remindsAtStart: false,
            completedAt: nil,
            subtasks: [Subtask(id: "a", title: "Agenda", isDone: true), Subtask(id: "b", title: "Notes")],
            source: .gmail, sourceTitle: "Re: review", sourceURL: URL(string: "https://mail.example.com/1"),
            sessions: [
                WorkSession(start: start, end: start.addingTimeInterval(600)),
                WorkSession(start: start.addingTimeInterval(900)),
            ],
            createdAt: start, editedAt: start.addingTimeInterval(60))
    }

    @Test func aTaskComesBackExactlyAsSaved() throws {
        let database = try AppDatabase.inMemory()
        var change = BoardChange.lists(from: [], to: [work, personal])
        change.savedTasks = [rich]
        try database.apply(change)
        let board = try database.load()
        #expect(board.lists == [work, personal])
        #expect(board.tasks == [rich])
    }

    @Test func editsUpdateInPlaceAndKeepChildrenInStep() throws {
        let database = try AppDatabase.inMemory()
        var change = BoardChange.lists(from: [], to: [work])
        change.savedTasks = [rich]
        try database.apply(change)
        var edited = rich
        edited.title = "Weekly review, part 2"
        edited.subtasks.removeFirst()
        edited.sessions[1].end = start.addingTimeInterval(1_200)
        try database.apply(.tasks(from: [rich], to: [edited]))
        #expect(try database.load().tasks == [edited])
    }

    @Test func deletingAListTakesItsTasksWithIt() throws {
        let database = try AppDatabase.inMemory()
        var change = BoardChange.lists(from: [], to: [work, personal])
        change.savedTasks = [rich]
        try database.apply(change)
        try database.apply(.lists(from: [work, personal], to: [personal]))
        let board = try database.load()
        #expect(board.lists == [personal])
        #expect(board.tasks.isEmpty)
    }

    @Test func theDiffWritesOnlyWhatChanged() {
        var moved = rich
        moved.bucket = .today
        let other = TaskItem(id: "other", listID: "work", title: "Other", bucket: .backlog, rank: 1)
        let change = BoardChange.tasks(from: [rich, other], to: [moved])
        #expect(change.savedTasks == [moved])
        #expect(change.deletedTaskIDs == ["other"])
        #expect(BoardChange.tasks(from: [rich], to: [rich]).isEmpty)
    }

    @Test func preferencesAreKeptByKey() throws {
        let database = try AppDatabase.inMemory()
        try database.setPreference("25", for: "sprintMinutes")
        try database.setPreference("30", for: "sprintMinutes")
        #expect(try database.load().preferences == ["sprintMinutes": "30"])
    }

    @Test func localDatesReadBackTheirOwnForm() {
        #expect(LocalDate(iso: "2026-10-02") == LocalDate(year: 2026, month: 10, day: 2))
        #expect(LocalDate(iso: "2026-13-02") == nil)
    }
}
