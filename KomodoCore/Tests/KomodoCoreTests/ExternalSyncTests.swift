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

struct ExternalSyncPullTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    // Thursday 1 October 2026, 08:00 UTC.
    let now = Date(timeIntervalSince1970: 1_790_841_600)
    var today: LocalDate { LocalDate(now, calendar: calendar) }
    var context: ExternalSync.Context {
        ExternalSync.Context(
            connectionID: "todoist", source: .todoist, listID: "work", sourceTitle: "Komodo launch", onlyMine: false,
            syncsDeletes: false, connectedAt: now.addingTimeInterval(-86_400),
            week: WeekRange(containing: today, calendar: calendar), now: now)
    }

    func item(_ id: String, _ title: String, day: Int? = nil, updated: TimeInterval = 0) -> ExternalItem {
        ExternalItem(
            id: id, title: title, date: day.map { today.adding(days: $0, calendar: calendar) }, minute: nil,
            updatedAt: now.addingTimeInterval(updated), url: Todoist.taskURL(id))
    }

    /// Imports `items` into an empty list and returns the board and links as they'd be saved.
    func imported(_ items: [ExternalItem]) -> (board: [TaskItem], links: [ExternalLink]) {
        let result = ExternalSync.pull(items, links: [], board: [], known: [], context: context)
        return (result.saved, result.links)
    }

    @Test func newItemsArePlacedByDateWithALinkEach() {
        let result = imported([item("1", "Write post", day: 0), item("2", "Record demo", day: 2), item("3", "Ideas")])
        let byTitle = Dictionary(uniqueKeysWithValues: result.board.map { ($0.title, $0) })
        #expect(byTitle["Write post"]?.column(in: context.week) == .today)
        #expect(byTitle["Record demo"]?.column(in: context.week) == .week)
        #expect(byTitle["Ideas"]?.column(in: context.week) == .backlog)
        #expect(result.board.allSatisfy { $0.source == .todoist && $0.sourceTitle == "Komodo launch" })
        #expect(result.board.map(\.id) == ["todoist:1", "todoist:2", "todoist:3"])
        #expect(result.links.map(\.taskID) == result.board.map(\.id))
    }

    @Test func doneDeletedAndOthersItemsAreNotImported() {
        var done = item("1", "Done already")
        done.isDone = true
        var gone = item("2", "Deleted")
        gone.isDeleted = true
        var theirs = item("3", "Someone else's")
        theirs.isMine = false
        var mineOnly = context
        mineOnly.onlyMine = true
        #expect(
            ExternalSync.pull([done, gone, theirs], links: [], board: [], known: [], context: mineOnly).saved.isEmpty)
        #expect(imported([theirs]).board.count == 1)
    }

    @Test func aTaskDeletedInKomodoIsNotImportedAgain() {
        let result = ExternalSync.pull(
            [item("1", "Write post")], links: [], board: [], known: ["todoist:1"], context: context)
        #expect(result.saved.isEmpty && result.links.isEmpty)
    }

    @Test func aRemoteEditUpdatesTheTaskAndItsLink() {
        let first = imported([item("1", "Write post", day: 3)])
        let edited = item("1", "Write the launch post", day: 0, updated: 60)
        let result = ExternalSync.pull([edited], links: first.links, board: first.board, known: [], context: context)
        #expect(result.saved.map(\.title) == ["Write the launch post"])
        #expect(result.saved.first?.scheduledDate == today)
        #expect(result.links.first?.snapshot == edited.snapshot)
        #expect(result.links.first?.remoteUpdatedAt == edited.updatedAt)
    }

    @Test func aRemoteCompletionFinishesTheTask() {
        let first = imported([item("1", "Write post")])
        var done = item("1", "Write post", updated: 60)
        done.isDone = true
        let result = ExternalSync.pull([done], links: first.links, board: first.board, known: [], context: context)
        #expect(result.saved.first?.completedAt == done.updatedAt)
    }

    @Test func aRemoteDeleteOnlyUnlinks() {
        var first = imported([item("1", "Write post")])
        first.board[0].notes = "Outline in my notebook"
        var gone = item("1", "Write post", updated: 60)
        gone.isDeleted = true
        let result = ExternalSync.pull([gone], links: first.links, board: first.board, known: [], context: context)
        #expect(result.links.isEmpty)
        // Still marked as from Todoist, so it isn't sent back as a new item, but it no longer opens there.
        #expect(result.saved.first?.source == .todoist && result.saved.first?.sourceURL == nil)
        #expect(result.saved.first?.notes == "Outline in my notebook")
        #expect(
            ExternalSync.pushes(
                links: result.links, board: result.saved, known: [], trash: [], context: context
            ).isEmpty)
    }

    @Test func aFullSyncUnlinksItemsItNoLongerLists() {
        let first = imported([item("1", "Write post"), item("2", "Record demo")])
        let result = ExternalSync.pull(
            [item("1", "Write post")], links: first.links, board: first.board, known: [], context: context,
            isEverything: true)
        #expect(result.links.map(\.externalID) == ["1"])
        #expect(result.saved.map(\.title) == ["Record demo"])
        #expect(result.saved.first?.sourceURL == nil)
    }

    @Test func finishingARepeatingItemKeepsTheTaskAndAddsTheNextOne() {
        var first = imported([item("1", "Water plants", day: 0)])
        first.board[0].completedAt = now
        first.board[0].sessions = [WorkSession(start: now.addingTimeInterval(-600), end: now)]
        first.links[0].snapshot = ExternalItem.snapshot(of: first.board[0])
        var next = item("1", "Water plants", day: 7, updated: 60)
        next.repeats = true
        let result = ExternalSync.pull([next], links: first.links, board: first.board, known: [], context: context)
        #expect(result.saved.count == 2)
        let done = result.saved[0]
        #expect(done.id == first.board[0].id && done.isDone && done.sessions.count == 1)
        let upcoming = result.saved[1]
        #expect(!upcoming.isDone && upcoming.scheduledDate == today.adding(days: 7, calendar: calendar))
        #expect(upcoming.sessions.isEmpty && upcoming.source == .todoist)
        #expect(result.links.map(\.taskID) == [upcoming.id])
    }

    @Test func whenBothSidesChangedTheNewerEditWins() {
        let first = imported([item("1", "Write post")])
        var local = first.board
        local[0].title = "Write post tonight"
        local[0].editedAt = now.addingTimeInterval(120)
        let older = item("1", "Write post today", updated: 60)
        let kept = ExternalSync.pull([older], links: first.links, board: local, known: [], context: context)
        #expect(kept.saved.isEmpty)
        #expect(kept.links.first?.snapshot == first.links.first?.snapshot)
        let newer = item("1", "Write post today", updated: 180)
        let taken = ExternalSync.pull([newer], links: first.links, board: local, known: [], context: context)
        #expect(taken.saved.map(\.title) == ["Write post today"])
    }

    @Test func aRemoteNotesEditDropsTheStaleFormatting() {
        var first = imported([item("1", "Write post")])
        first.board[0].notes = "Old"
        first.board[0].notesRTF = Data([1])
        first.links[0].snapshot = ExternalItem.snapshot(of: first.board[0])
        var edited = item("1", "Write post", updated: 60)
        edited.notes = "New"
        let result = ExternalSync.pull([edited], links: first.links, board: first.board, known: [], context: context)
        #expect(result.saved.first?.notes == "New")
        #expect(result.saved.first?.notesRTF == nil)
    }
}

struct ExternalSyncPushTests {
    let pull = ExternalSyncPullTests()

    func pushes(
        _ links: [ExternalLink], _ board: [TaskItem], trash: Set<String> = [], syncsDeletes: Bool = false
    ) -> [ExternalSync.Push] {
        var context = pull.context
        context.syncsDeletes = syncsDeletes
        let known = Set(board.map(\.id)).union(trash)
        return ExternalSync.pushes(links: links, board: board, known: known, trash: trash, context: context)
    }

    @Test func nothingIsSentWhileBothSidesAgree() {
        let first = pull.imported([pull.item("1", "Write post", day: 0)])
        #expect(pushes(first.links, first.board).isEmpty)
    }

    @Test func aLocalEditSendsOnlyTheFieldsThatChanged() {
        var first = pull.imported([pull.item("1", "Write post", day: 0)])
        first.board[0].title = "Write the post"
        first.board[0].completedAt = pull.now
        first.board[0].sessions = [WorkSession(start: pull.now)]
        #expect(
            pushes(first.links, first.board) == [
                .update(externalID: "1", task: first.board[0], changes: [.title, .done])
            ])
    }

    @Test func newTasksInTheListAreSentButOlderAndImportedOnesAreNot() {
        let new = TaskItem(id: "n", listID: "work", title: "New", bucket: .today, rank: 1, createdAt: pull.now)
        var old = new
        old.id = "o"
        old.createdAt = pull.now.addingTimeInterval(-2 * 86_400)
        var other = new
        other.id = "x"
        other.listID = "personal"
        var repeating = new
        repeating.id = "r"
        repeating.repeatRule = RepeatRule(interval: 1, unit: .day)
        var unlinked = new
        unlinked.id = "todoist:9"
        #expect(pushes([], [new, old, other, repeating, unlinked]) == [.add(new)])
    }

    @Test func deletesAreSentOnlyWithSyncDeletesOn() {
        let first = pull.imported([pull.item("1", "Write post"), pull.item("2", "Record demo")])
        let rest = Array(first.board.dropFirst())
        #expect(pushes(first.links, rest, trash: ["todoist:1"]).isEmpty)
        #expect(pushes(first.links, rest, trash: ["todoist:1"], syncsDeletes: true) == [.delete(externalID: "1")])
        // Purged from Trash before a sync could send it.
        #expect(pushes(first.links, rest, syncsDeletes: true) == [.delete(externalID: "1")])
    }
}

struct ExternalSyncConfirmTests {
    let pull = ExternalSyncPullTests()

    @Test func acceptedPushesRewriteTheLinks() {
        var first = pull.imported([pull.item("1", "Write post"), pull.item("2", "Record demo")])
        first.board[0].title = "Write the post"
        let new = TaskItem(id: "n", listID: "work", title: "New", bucket: .today, rank: 1, createdAt: pull.now)
        let pushes: [ExternalSync.Push] = [
            .update(externalID: "1", task: first.board[0], changes: [.title]), .delete(externalID: "2"), .add(new),
        ]
        let url = Todoist.taskURL("3")
        var renamed = new
        renamed.title = "New, renamed while it was sent"
        let result = ExternalSync.confirm(
            pushes, outcomes: [.accepted, .accepted, .added(externalID: "3", url: url)], links: first.links,
            board: first.board + [renamed], context: pull.context)
        #expect(result.links.map(\.externalID) == ["1", "3"])
        #expect(result.links[0].snapshot == ExternalItem.snapshot(of: first.board[0]))
        #expect(result.links[1].taskID == "n")
        #expect(result.saved.map(\.title) == [renamed.title])
        // The link holds what Todoist was sent, so the rename goes on the next sync.
        #expect(result.links[1].snapshot == ExternalItem.snapshot(of: new))
        #expect(result.saved.first?.source == .todoist && result.saved.first?.sourceURL == url)
        #expect(result.refusals.isEmpty)
    }

    @Test func aRefusedPushIsTriedAgainNextTime() {
        var first = pull.imported([pull.item("1", "Write post")])
        first.board[0].title = "Write the post"
        let push = ExternalSync.Push.update(externalID: "1", task: first.board[0], changes: [.title])
        let result = ExternalSync.confirm(
            [push], outcomes: [.refused("Item not found")], links: first.links, board: first.board,
            context: pull.context)
        #expect(result.links == first.links)
        #expect(result.refusals == ["Item not found"])
    }

    @Test func aPushToAnItemThatsGoneUnlinksInsteadOfRetrying() {
        var first = pull.imported([pull.item("1", "Write post"), pull.item("2", "Record demo")])
        first.board[0].title = "Write the post"
        let result = ExternalSync.confirm(
            [.update(externalID: "1", task: first.board[0], changes: [.title]), .delete(externalID: "2")],
            outcomes: [.gone, .gone], links: first.links, board: first.board, context: pull.context)
        #expect(result.links.isEmpty && result.refusals.isEmpty)
        #expect(result.saved.map(\.title) == ["Write the post"])
        #expect(result.saved.first?.sourceURL == nil)
    }
}

struct ExternalSyncEstimateTests {
    let pull = ExternalSyncPullTests()

    @Test func anUndatedTaskKeepsItsEstimateThroughARemoteEdit() {
        var first = pull.imported([pull.item("1", "Write post")])
        first.board[0].estimate = 1_800
        #expect(ExternalItem.snapshot(of: first.board[0]) == first.links[0].snapshot)
        let renamed = pull.item("1", "Write the post", updated: 60)
        let result = ExternalSync.pull(
            [renamed], links: first.links, board: first.board, known: [], context: pull.context)
        #expect(result.saved.first?.estimate == 1_800)
    }
}

struct ExternalSyncShapeTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    // Thursday 1 October 2026, 08:00 UTC.
    let now = Date(timeIntervalSince1970: 1_790_841_600)
    var today: LocalDate { LocalDate(now, calendar: calendar) }

    func context(_ provider: Provider, _ mapping: DateMapping = .start) -> ExternalSync.Context {
        ExternalSync.Context(
            connectionID: provider.rawValue, source: provider.source, listID: "work", sourceTitle: "Launch",
            onlyMine: false, syncsDeletes: false, connectedAt: now.addingTimeInterval(-86_400),
            week: WeekRange(containing: today, calendar: calendar), now: now, shape: provider.shape(mapping))
    }

    @Test func todoistLinksFromBeforeTheNewFieldsReadTheSame() {
        let item = ExternalItem(id: "1", title: "Write post", date: today, minute: 900, estimate: 2_700)
        #expect(
            item.snapshot == ["Write post", "", today.description, "900", "", "45", "0"].joined(separator: "\u{1F}"))
        #expect(ExternalItem.changes(from: item.snapshot, to: item.snapshot + "\u{1F}\u{1F}").isEmpty)
    }

    @Test func aFieldTheProviderDoesntKeepStaysAsKomodoHasIt() {
        let linear = context(.linear)
        let imported = ExternalSync.pull(
            [ExternalItem(id: "ENG-1", title: "Fix login", date: today)], links: [], board: [], known: [],
            context: linear)
        var task = imported.saved[0]
        task.estimate = 1_800
        task.dueDate = today
        #expect(ExternalItem.snapshot(of: task, linear.shape) == imported.links[0].snapshot)
        let renamed = ExternalItem(id: "ENG-1", title: "Fix the login", date: today, updatedAt: now)
        let pulled = ExternalSync.pull(
            [renamed], links: imported.links, board: [task], known: [], context: linear)
        #expect(pulled.saved.first?.estimate == 1_800 && pulled.saved.first?.dueDate == today)
    }

    @Test func anUndatedItemGoesToTheColumnItsStatusMapsTo() {
        let clickup = context(.clickup)
        let items = [
            ExternalItem(id: "1", title: "Doing", bucket: .today),
            ExternalItem(id: "2", title: "Dated", date: today.adding(days: 3, calendar: calendar), bucket: .today),
            ExternalItem(id: "3", title: "Open"),
        ]
        let board = ExternalSync.pull(items, links: [], board: [], known: [], context: clickup).saved
        #expect(board.map { $0.column(in: clickup.week) } == [.today, .week, .backlog])
    }

    @Test func movingAnUndatedTaskToAnotherColumnIsAnEdit() {
        let clickup = context(.clickup)
        let first = ExternalSync.pull(
            [ExternalItem(id: "1", title: "Doing", bucket: .today)], links: [], board: [], known: [],
            context: clickup)
        var moved = first.saved[0]
        moved.bucket = .week
        let pushes = ExternalSync.pushes(links: first.links, board: [moved], known: [], trash: [], context: clickup)
        #expect(pushes == [.update(externalID: "1", task: moved, changes: [.column])])
        let todoist = context(.todoist)
        let plain = ExternalSync.pull(
            [ExternalItem(id: "1", title: "Doing")], links: [], board: [], known: [], context: todoist)
        var dragged = plain.saved[0]
        dragged.bucket = .today
        #expect(
            ExternalSync.pushes(links: plain.links, board: [dragged], known: [], trash: [], context: todoist).isEmpty)
    }

    @Test func subtasksComeFromProvidersThatHaveThem() {
        let notion = context(.notion)
        let item = ExternalItem(
            id: "p", title: "Ship", subtasks: [Subtask(id: "p:a", title: "Reviewed", isDone: true)])
        let first = ExternalSync.pull([item], links: [], board: [], known: [], context: notion)
        #expect(first.saved[0].subtasks.map(\.title) == ["Reviewed"])
        var ticked = first.saved[0]
        ticked.subtasks[0].isDone = false
        let pushes = ExternalSync.pushes(links: first.links, board: [ticked], known: [], trash: [], context: notion)
        #expect(pushes == [.update(externalID: "p", task: ticked, changes: [.subtasks])])
    }

    @Test func withDueMappingKomodosDueDateStaysLocal() {
        let asana = context(.asana, .due)
        let first = ExternalSync.pull(
            [ExternalItem(id: "1", title: "Brief", date: today)], links: [], board: [], known: [], context: asana)
        var task = first.saved[0]
        task.dueDate = today
        #expect(ExternalSync.pushes(links: first.links, board: [task], known: [], trash: [], context: asana).isEmpty)
    }

    @Test func aFullReadKeepsFinishedItemsItDoesntList() {
        let asana = context(.asana)
        var done = ExternalItem(id: "1", title: "Sent", isDone: true)
        let first = ExternalSync.pull(
            [ExternalItem(id: "1", title: "Sent"), ExternalItem(id: "2", title: "Gone")], links: [], board: [],
            known: [], context: asana)
        done.updatedAt = now
        let finished = ExternalSync.pull([done], links: first.links, board: first.saved, known: [], context: asana)
        let full = ExternalSync.pull(
            [], links: finished.links, board: first.saved, known: [], context: asana, isEverything: true)
        #expect(full.links.map(\.externalID) == ["1"])
    }
}
