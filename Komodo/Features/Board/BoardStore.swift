import KomodoCore
import SwiftUI

/// The Board's state and actions over in-memory tasks until the database lands (ARCHITECTURE §4.2). Views read
/// derived values from here and send intents; every column, count and projection is computed, never stored.
@MainActor @Observable final class BoardStore {
    /// Focus mode's state beside the tasks themselves. The clock lives in the live task's sessions.
    struct Focus: Equatable {
        var taskID: String?
        /// Time taken when the task last resumed; the Flow chip counts from here.
        var flowStartedAt: TimeInterval = 0
        var breakEndsAt: Date?
        /// The queue ran out: show the day summary until something new starts.
        var isDayWon = false
    }

    static let breakLength: TimeInterval = 5 * 60

    var lists: [TaskList]
    private(set) var tasks: [TaskItem]
    /// nil shows All lists.
    var selectedListID: String?
    private(set) var focus = Focus()
    var isPomodoroOn = true
    /// Filters cards by title, notes and subtasks until the command palette takes over search.
    var searchText = ""
    /// The list to return to from All lists.
    private(set) var lastListID: String?
    let toasts = ToastCenter()
    let calendar: Calendar
    private let clock: () -> Date

    init(
        lists: [TaskList], tasks: [TaskItem], selectedListID: String?, calendar: Calendar = .current,
        clock: @escaping () -> Date = { Date() }
    ) {
        self.lists = lists
        self.tasks = tasks
        self.selectedListID = selectedListID
        self.lastListID = selectedListID
        self.calendar = calendar
        self.clock = clock
        // A sample or restored open session means a task is already live.
        if let live = tasks.first(where: { task in task.sessions.contains { $0.end == nil } }) {
            focus.taskID = live.id
            focus.flowStartedAt = max(0, live.timeTaken(at: clock()) - 25 * 60)
        }
    }

    // MARK: Derived

    var now: Date { clock() }
    var today: LocalDate { LocalDate(now, calendar: calendar) }
    var week: WeekRange { WeekRange(containing: today, calendar: calendar) }
    var layout: BoardLayout {
        BoardLayout(tasks: visibleTasks, listID: selectedListID, week: week, calendar: calendar)
    }

    private var visibleTasks: [TaskItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return tasks }
        return tasks.filter { task in
            task.title.localizedStandardContains(query) || (task.notes ?? "").localizedStandardContains(query)
                || task.subtasks.contains { $0.title.localizedStandardContains(query) }
        }
    }

    func showList(_ id: String?) {
        selectedListID = id
        if let id { lastListID = id }
    }

    func showBoard() { showList(lastListID ?? lists.first?.id) }
    var selectedList: TaskList? { lists.first { $0.id == selectedListID } }
    var isFocusing: Bool { focus.taskID != nil || focus.breakEndsAt != nil }

    var liveTask: TaskItem? {
        guard let id = focus.taskID, focus.breakEndsAt == nil else { return nil }
        return tasks.first { $0.id == id }
    }

    /// Up next without the live task, which shows in its own card.
    var queue: [TaskItem] { layout.upNext.filter { $0.id != focus.taskID } }

    func dayPlan() -> DayPlan {
        let layout = self.layout
        let live = focus.taskID.flatMap { id in tasks.first { $0.id == id } }
        return DayPlan(
            now: now, live: live, queue: layout.upNext.filter { $0.id != live?.id },
            scheduled: layout.scheduledToday, doneToday: layout.doneToday, allTasks: tasks, today: today,
            calendar: calendar)
    }

    func openCount(listID: String?) -> Int {
        tasks.filter { !$0.isDone && (listID == nil || $0.listID == listID) }.count
    }

    func list(for task: TaskItem) -> TaskList? { lists.first { $0.id == task.listID } }

    /// How far the Board's clock runs ahead of the wall clock. Zero in normal use; sample data anchored to the
    /// artboard's afternoon sets it, and timelines that read the wall clock subtract it.
    var clockOffset: TimeInterval { now.timeIntervalSince(Date()) }

    /// The live task's clock, rebuilt from its sessions: closed ones add up, an open one is running. Expressed
    /// on the wall clock because the dial redraws from `TimelineView` dates.
    func focusClock(for task: TaskItem) -> FocusClock {
        let closed = task.sessions.filter { $0.end != nil }.reduce(0) { $0 + $1.duration(until: now) }
        let running = task.sessions.first { $0.end == nil }?.start.addingTimeInterval(-clockOffset)
        return FocusClock(accumulated: closed, runningSince: running)
    }

    /// The break's end on the wall clock, for the countdown's `TimelineView`.
    var breakEndsAtWallClock: Date? { focus.breakEndsAt?.addingTimeInterval(-clockOffset) }

    // MARK: Tasks

    /// Adds a task to a column. A trailing estimate in the title becomes the EST (FEATURES §4.3).
    @discardableResult
    func addTask(_ rawTitle: String, to bucket: Bucket, atTop: Bool = false, estimate: TimeInterval? = nil)
        -> TaskItem?
    {
        let parsed = EstimateParser.parse(rawTitle)
        guard !parsed.title.isEmpty else { return nil }
        let listID = selectedListID ?? lists.first?.id ?? ""
        let ranks = tasks.filter { $0.column(in: week) == bucket && !$0.isDone }.map(\.rank)
        let rank = atTop ? (ranks.min() ?? 0) - 1 : (ranks.max() ?? 0) + 1
        let task = TaskItem(
            id: UUID().uuidString, listID: listID, title: parsed.title, bucket: bucket, rank: rank,
            estimate: estimate ?? parsed.estimate, createdAt: now)
        tasks.append(task)
        return task
    }

    func toggleDone(_ id: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let before = tasks[index]
        if before.isDone {
            tasks[index].completedAt = nil
            return
        }
        if focus.taskID == id {
            completeLive()
            return
        }
        tasks[index].completedAt = now
        offerUndo("Task completed", detail: before.title, restoring: before)
    }

    /// Moves a task to another column, before `beforeID` or at the bottom. A scheduled task loses its date so
    /// it stays where it was dropped (FEATURES §4.2), with Undo in case that wasn't the intent.
    func move(_ id: String, to bucket: Bucket, before beforeID: String? = nil) {
        guard let index = tasks.firstIndex(where: { $0.id == id }), id != beforeID else { return }
        let before = tasks[index]
        let neighbours = column(bucket).filter { $0.id != id }
        tasks[index].bucket = bucket
        tasks[index].rank = rank(inserting: beforeID, into: neighbours)
        if before.scheduledDate != nil && before.column(in: week) != bucket {
            tasks[index].scheduledDate = nil
            tasks[index].scheduledMinute = nil
        }
        if before.column(in: week) != bucket {
            offerUndo("Moved to \(Self.title(for: bucket))", detail: before.title, restoring: before)
        }
    }

    /// ⌥↑ / ⌥↓: swap with the neighbour above or below in the same column.
    func nudge(_ id: String, by offset: Int) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        let siblings = column(task.column(in: week))
        guard let position = siblings.firstIndex(where: { $0.id == id }) else { return }
        let target = position + offset
        guard siblings.indices.contains(target),
            let a = tasks.firstIndex(where: { $0.id == id }),
            let b = tasks.firstIndex(where: { $0.id == siblings[target].id })
        else { return }
        (tasks[a].rank, tasks[b].rank) = (tasks[b].rank, tasks[a].rank)
    }

    // MARK: Focus (FEATURES §4.8)

    /// Makes the first eligible Today task live.
    func start() {
        guard focus.taskID == nil, let first = layout.upNext.first else { return }
        begin(first.id)
    }

    /// The bolt: the current task pauses, keeps its time and goes back to the top of the queue.
    func makeLive(_ id: String) {
        if let current = focus.taskID, current != id {
            closeSession(current)
            if let index = tasks.firstIndex(where: { $0.id == current }) {
                tasks[index].rank = (layout.upNext.map(\.rank).min() ?? 0) - 1
            }
        }
        focus.breakEndsAt = nil
        begin(id)
    }

    func togglePause() {
        guard let id = focus.taskID, let task = tasks.first(where: { $0.id == id }) else { return }
        if focusClock(for: task).isRunning {
            closeSession(id)
        } else {
            openSession(id)
            focus.flowStartedAt = task.timeTaken(at: now)
        }
    }

    /// Moves the live task to the bottom of Up next, keeping its time, and starts the next one.
    func skip() {
        guard let id = focus.taskID else { return }
        closeSession(id)
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].rank = (layout.upNext.map(\.rank).max() ?? 0) + 1
        }
        focus.taskID = nil
        if let next = layout.upNext.first(where: { $0.id != id }) { begin(next.id) } else { begin(id) }
    }

    /// Done: completes the live task and starts the next eligible one, or wins the day.
    func completeLive() {
        guard let id = focus.taskID, let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        closeSession(id)
        tasks[index].completedAt = now
        focus.taskID = nil
        if let next = layout.upNext.first {
            begin(next.id)
        } else {
            focus.isDayWon = true
        }
    }

    func extendEstimate(by seconds: TimeInterval) {
        guard let id = focus.taskID, let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].estimate = (tasks[index].estimate ?? 0) + seconds
        if tasks[index].sessions.allSatisfy({ $0.end != nil }) { openSession(id) }
    }

    func takeBreak() {
        guard let id = focus.taskID else { return }
        closeSession(id)
        focus.breakEndsAt = now.addingTimeInterval(Self.breakLength)
    }

    func extendBreak(by seconds: TimeInterval) {
        focus.breakEndsAt = focus.breakEndsAt?.addingTimeInterval(seconds)
    }

    func endBreak() {
        focus.breakEndsAt = nil
        if let id = focus.taskID {
            openSession(id)
            focus.flowStartedAt = tasks.first { $0.id == id }?.timeTaken(at: now) ?? 0
        }
    }

    // MARK: Private

    private func begin(_ id: String) {
        focus.taskID = id
        focus.isDayWon = false
        openSession(id)
        focus.flowStartedAt = tasks.first { $0.id == id }?.timeTaken(at: now) ?? 0
    }

    private func openSession(_ id: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }),
            tasks[index].sessions.allSatisfy({ $0.end != nil })
        else { return }
        tasks[index].sessions.append(WorkSession(start: now))
    }

    private func closeSession(_ id: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }),
            let open = tasks[index].sessions.lastIndex(where: { $0.end == nil })
        else { return }
        tasks[index].sessions[open].end = now
    }

    private func column(_ bucket: Bucket) -> [TaskItem] {
        switch bucket {
        case .backlog: layout.backlog
        case .week: layout.week
        case .today: layout.upNext
        }
    }

    private func rank(inserting beforeID: String?, into column: [TaskItem]) -> Double {
        guard let beforeID, let position = column.firstIndex(where: { $0.id == beforeID }) else {
            return (column.map(\.rank).max() ?? 0) + 1
        }
        let next = column[position].rank
        let previous = position > 0 ? column[position - 1].rank : next - 2
        return (previous + next) / 2
    }

    private func offerUndo(_ message: String, detail: String, restoring snapshot: TaskItem) {
        toasts.show(
            Toast(
                message: message, detail: detail,
                action: .init(title: "Undo", shortcut: "⌘Z") { [weak self] in
                    guard let self, let index = self.tasks.firstIndex(where: { $0.id == snapshot.id }) else { return }
                    self.tasks[index] = snapshot
                }))
    }

    static func title(for bucket: Bucket) -> String {
        switch bucket {
        case .backlog: "Backlog"
        case .week: "This week"
        case .today: "Today"
        }
    }
}
