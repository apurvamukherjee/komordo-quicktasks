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
        /// The break's full length including any +2 min, for its ring and "of 05:00 break".
        var breakLength: TimeInterval = 0
        /// The queue ran out: show the day summary until something new starts.
        var isDayWon = false
    }

    enum FocusSurface: Sendable {
        case panel
        case floatingTimer
    }

    /// The screen edge the Focus Panel docks to.
    enum PanelSide: String, CaseIterable, Sendable {
        case left
        case right
    }

    var lists: [TaskList]
    private(set) var tasks: [TaskItem]
    /// nil shows All lists.
    var selectedListID: String?
    private(set) var focus = Focus()
    var isPomodoroOn = true
    // Quick Settings (DESIGN_SYSTEM §13.8), in memory until Settings persist them.
    var sprintLength: TimeInterval = 25 * 60
    /// Also the length of a break started by hand (FEATURES §4.11).
    var breakLength: TimeInterval = 5 * 60
    var panelSide = PanelSide.right
    var playsSounds = true
    /// Where Focus mode shows while the Home window steps aside (FEATURES §4.8, §4.9); nil shows Home.
    var focusSurface: FocusSurface?
    /// Bumped by ⌘⇧P; the floating timer ripples each time it changes.
    private(set) var locatorPings = 0
    /// Filters cards by title, notes and subtasks until the command palette takes over search.
    var searchText = ""
    /// The task open in the inspector (DESIGN_SYSTEM §13.5); nil when it's closed.
    var inspectedTaskID: String?
    /// The card showing the Schedule popover, whether it was opened from the hover row, ⋯ or right-click.
    var schedulingTaskID: String?
    /// The ⌘⌥T quick add panel (DESIGN_SYSTEM §13.4).
    var isQuickAddOpen = false
    /// The list to return to from All lists.
    private(set) var lastListID: String?
    /// Children of recurring tasks deleted by hand, so expanding the week doesn't bring them back.
    private var dismissedChildren: Set<String> = []
    let toasts = ToastCenter()
    /// The window's, so ⌘Z and Edit ▸ Undo reach the same restore as the toast's button. Set by `HomeView`.
    weak var undoManager: UndoManager?
    let calendar: Calendar
    private let clock: () -> Date
    private let openURL: (URL) -> Void

    init(
        lists: [TaskList], tasks: [TaskItem], selectedListID: String?, calendar: Calendar = .current,
        clock: @escaping () -> Date = { Date() }, openURL: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) }
    ) {
        self.lists = lists
        self.tasks = tasks
        self.selectedListID = selectedListID
        self.lastListID = selectedListID
        self.calendar = calendar
        self.clock = clock
        self.openURL = openURL
        // A sample or restored open session means a task is already live.
        if let live = tasks.first(where: { task in task.sessions.contains { $0.end == nil } }) {
            focus.taskID = live.id
            focus.flowStartedAt = max(0, live.timeTaken(at: clock()) - 25 * 60)
        }
        expandRecurrences()
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

    /// Adds a task to a column. A trailing estimate in the title becomes the EST (FEATURES §4.3). Without a
    /// list it goes to the one on screen, or the last one used from All lists (DESIGN_SYSTEM §13.3).
    @discardableResult
    func addTask(
        _ rawTitle: String, to bucket: Bucket, listID: String? = nil, atTop: Bool = false,
        estimate: TimeInterval? = nil
    ) -> TaskItem? {
        let parsed = EstimateParser.parse(rawTitle)
        guard !parsed.title.isEmpty else { return nil }
        let listID = listID ?? selectedListID ?? lastListID ?? lists.first?.id ?? ""
        let ranks = tasks.filter { $0.column(in: week) == bucket && !$0.isDone }.map(\.rank)
        let rank = atTop ? (ranks.min() ?? 0) - 1 : (ranks.max() ?? 0) + 1
        let task = TaskItem(
            id: UUID().uuidString, listID: listID, title: parsed.title, bucket: bucket, rank: rank,
            estimate: estimate ?? parsed.estimate, createdAt: now)
        tasks.append(task)
        return task
    }

    /// ⌘Return in quick add (DESIGN_SYSTEM §13.4): adds the task to Today and makes it live.
    func addAndStart(_ rawTitle: String, listID: String? = nil, estimate: TimeInterval? = nil) {
        guard let task = addTask(rawTitle, to: .today, listID: listID, atTop: true, estimate: estimate) else {
            return
        }
        makeLive(task.id)
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

    // MARK: Inspector (DESIGN_SYSTEM §13.5)

    var inspectedTask: TaskItem? { inspectedTaskID.flatMap { id in tasks.first { $0.id == id } } }

    /// Board order, left to right and top to bottom, for ⌘↑ / ⌘↓.
    var inspectorOrder: [TaskItem] {
        let layout = self.layout
        return layout.backlog + layout.week + layout.upNext + layout.scheduledToday + layout.doneToday
    }

    func inspect(_ id: String?) { inspectedTaskID = id }

    func inspectAdjacent(_ offset: Int) {
        let order = inspectorOrder
        guard let id = inspectedTaskID, let position = order.firstIndex(where: { $0.id == id }),
            order.indices.contains(position + offset)
        else { return }
        inspectedTaskID = order[position + offset].id
    }

    /// A running task's title and EST are locked, and so is its time taken (FEATURES §4.3).
    func isRunning(_ task: TaskItem) -> Bool { task.sessions.contains { $0.end == nil } }

    /// Every inspector edit goes through here so "Edited … ago" stays true.
    func update(_ id: String, _ change: (inout TaskItem) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        change(&tasks[index])
        tasks[index].editedAt = now
    }

    func rename(_ id: String, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let task = tasks.first(where: { $0.id == id }), !isRunning(task) else { return }
        update(id) { $0.title = trimmed }
    }

    func setEstimate(_ id: String, to estimate: TimeInterval) {
        guard let task = tasks.first(where: { $0.id == id }), !isRunning(task) else { return }
        update(id) { $0.estimate = estimate }
    }

    func setTimeTaken(_ id: String, to taken: TimeInterval) {
        let now = self.now
        update(id) { $0.setTimeTaken(taken, at: now) }
    }

    func addSubtask(to id: String, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        update(id) { $0.subtasks.append(Subtask(id: UUID().uuidString, title: trimmed)) }
    }

    func updateSubtask(_ subtaskID: String, of id: String, _ change: (inout Subtask) -> Void) {
        update(id) { task in
            guard let index = task.subtasks.firstIndex(where: { $0.id == subtaskID }) else { return }
            change(&task.subtasks[index])
        }
    }

    func deleteSubtask(_ subtaskID: String, of id: String) {
        update(id) { $0.subtasks.removeAll { $0.id == subtaskID } }
    }

    /// A fresh copy just below the original: same details, no time, not done.
    func duplicate(_ id: String) {
        guard let original = tasks.first(where: { $0.id == id }) else { return }
        var copy = original
        copy.id = UUID().uuidString
        copy.rank = original.rank + 0.5
        copy.sessions = []
        copy.completedAt = nil
        copy.createdAt = now
        copy.editedAt = nil
        copy.subtasks = original.subtasks.map { Subtask(id: UUID().uuidString, title: $0.title) }
        tasks.append(copy)
        inspectedTaskID = copy.id
    }

    /// Removes a task with Undo. Trash comes later (FEATURES §4.20); until then Undo is the way back.
    func delete(_ id: String) {
        // A deleted live task stops its clock first, so Undo brings it back paused rather than running unseen.
        if focus.taskID == id {
            closeSession(id)
            focus = Focus()
        }
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let removed = tasks.remove(at: index)
        if inspectedTaskID == id { inspectedTaskID = nil }
        if removed.repeatParentID != nil { dismissedChildren.insert(id) }
        offerUndo("Task deleted", detail: removed.title) { store in
            guard !store.tasks.contains(where: { $0.id == removed.id }) else { return }
            store.dismissedChildren.remove(removed.id)
            store.tasks.append(removed)
        }
    }

    // MARK: Schedule and repeat (FEATURES §4.6–4.7)

    /// What the Schedule popover saves: a day, an optional time, an optional repeat and the reminder switch.
    struct Schedule: Equatable {
        var date: LocalDate
        /// Minutes after midnight; nil is all day.
        var minute: Int?
        var rule: RepeatRule?
        var remindsAtStart = true
        /// Replace existing tasks (a changed repeat) or Delete existing tasks (repeat turned off).
        var clearsExisting = false
    }

    /// The task whose rule a task's Repeat row edits: itself, or the parent a child was made from.
    func repeatOwner(of task: TaskItem) -> TaskItem? {
        guard let parentID = task.repeatParentID else { return task }
        return tasks.first { $0.id == parentID }
    }

    /// The popover's starting point for `task`: its day and time, or today with nothing else set.
    func schedule(for task: TaskItem) -> Schedule {
        let owner = repeatOwner(of: task)
        return Schedule(
            date: task.scheduledDate ?? owner?.repeatStart ?? today, minute: task.scheduledMinute,
            rule: owner?.repeatRule, remindsAtStart: task.remindsAtStart)
    }

    func repeatSummary(for task: TaskItem) -> String? {
        guard let owner = repeatOwner(of: task), let rule = owner.repeatRule, let start = owner.repeatStart else {
            return nil
        }
        return rule.summary(from: start, calendar: calendar)
    }

    /// Saves the popover. Without a repeat the task simply moves to its day. With one it becomes the recurring
    /// parent: it holds the rule in Backlog and this week's copies appear on their days.
    func setSchedule(_ id: String, to schedule: Schedule) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        let ownerID = repeatOwner(of: task)?.id ?? id
        if schedule.clearsExisting { tasks = Recurrence.removingUnfinishedChildren(of: ownerID, from: tasks) }
        if let rule = schedule.rule {
            update(ownerID) {
                $0.repeatRule = rule
                $0.repeatStart = schedule.date
                $0.scheduledDate = nil
                $0.scheduledMinute = schedule.minute
                $0.remindsAtStart = schedule.remindsAtStart
                $0.bucket = .backlog
            }
            if ownerID != id {
                // A child keeps its own day; only the rule moved to the parent.
                update(id) {
                    $0.scheduledMinute = schedule.minute
                    $0.remindsAtStart = schedule.remindsAtStart
                }
            }
        } else {
            update(ownerID) {
                $0.repeatRule = nil
                $0.repeatStart = nil
            }
            update(id) {
                $0.scheduledDate = schedule.date
                $0.scheduledMinute = schedule.minute
                $0.remindsAtStart = schedule.remindsAtStart
            }
        }
        expandRecurrences()
    }

    /// Remove schedule: the task goes back to the column it was parked in, without a day, time or repeat.
    func removeSchedule(_ id: String) {
        guard let task = tasks.first(where: { $0.id == id }) else { return }
        let before = task
        update(id) {
            $0.scheduledDate = nil
            $0.scheduledMinute = nil
            $0.repeatRule = nil
            $0.repeatStart = nil
        }
        offerUndo("Schedule removed", detail: before.title, restoring: before)
    }

    /// Makes this week's missing children of every recurring task. Runs at launch and after every schedule
    /// change; midnight and wake come with persistence.
    func expandRecurrences() {
        tasks = Recurrence.expanding(tasks, in: week, dismissed: dismissedChildren, calendar: calendar)
    }

    // MARK: Focus (FEATURES §4.8)

    /// Makes the first eligible Today task live and docks the Focus Panel.
    func start() {
        guard focus.taskID == nil, let first = layout.upNext.first else { return }
        begin(first.id)
        focusSurface = .panel
    }

    /// Home: back to the Board, where Focus mode carries on in the Today stage.
    func exitFocusMode() { focusSurface = nil }

    /// ⌘⇧T: the panel and the floating timer swap. From Home it collapses straight to the timer.
    func toggleFloatingTimer() {
        guard isFocusing || focusSurface != nil else { return }
        focusSurface = focusSurface == .floatingTimer ? .panel : .floatingTimer
    }

    /// ⌘⇧P: the floating timer ripples so it can be found on a busy screen.
    func locateFloatingTimer() {
        guard focusSurface == .floatingTimer else { return }
        locatorPings += 1
    }

    /// Done on the day summary: nothing is left to focus on, so Focus mode ends and Home comes back.
    func closeDaySummary() {
        focus.isDayWon = false
        focusSurface = nil
    }

    /// The next task with a time today, once nothing else is left to run.
    var nextScheduled: TaskItem? {
        layout.upNext.isEmpty && focus.taskID == nil && !focus.isDayWon ? layout.scheduledToday.first : nil
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

    /// Done: completes the live task and starts the next eligible one. With only timed tasks left the panel
    /// waits for them; with nothing left the day is won.
    func completeLive() {
        guard let id = focus.taskID, let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        closeSession(id)
        tasks[index].completedAt = now
        focus.taskID = nil
        if let next = layout.upNext.first {
            begin(next.id)
        } else {
            focus.isDayWon = layout.scheduledToday.isEmpty
            // The summary and the calm card need the panel's room, so the floating timer opens back into it.
            if focusSurface == .floatingTimer { focusSurface = .panel }
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
        focus.breakEndsAt = now.addingTimeInterval(breakLength)
        focus.breakLength = breakLength
    }

    func extendBreak(by seconds: TimeInterval) {
        guard let endsAt = focus.breakEndsAt else { return }
        // Once the break has run out, +2 min counts from now rather than from when it ended.
        focus.breakEndsAt = max(endsAt, now).addingTimeInterval(seconds)
        focus.breakLength += max(0, now.timeIntervalSince(endsAt)) + seconds
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
        tasks.first { $0.id == id }?.linksToOpen.forEach(openURL)
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
        offerUndo(message, detail: detail) { store in
            guard let index = store.tasks.firstIndex(where: { $0.id == snapshot.id }) else { return }
            store.tasks[index] = snapshot
        }
    }

    private func offerUndo(_ message: String, detail: String, restore: @escaping @MainActor (BoardStore) -> Void) {
        // Each change gets its own target so the toast's button can withdraw just its menu entry; the undo
        // manager holds targets weakly, and the closures below keep this one alive.
        let token = NSObject()
        undoManager?.registerUndo(withTarget: token) { [weak self] _ in
            guard let self else { return }
            restore(self)
        }
        undoManager?.setActionName(message)
        toasts.show(
            Toast(
                message: message, detail: detail,
                action: .init(title: "Undo", shortcut: "⌘Z") { [weak self] in
                    guard let self else { return }
                    restore(self)
                    self.undoManager?.removeAllActions(withTarget: token)
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
