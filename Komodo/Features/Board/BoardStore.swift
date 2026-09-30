import KomodoCore
import OSLog
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
        /// Done was just pressed: the celebration plays before the next task starts (FEATURES §4.13).
        var celebration: Celebration?
        var pomodoro = PomodoroCycle()
        /// When the current stretch of work began, for the sprint; nil while nothing runs.
        var sprintSince: Date?
    }

    /// What the celebration says: the result against the estimate and what comes next.
    struct Celebration: Equatable {
        var taskID: String
        var title: String
        var message: String
        var nextTitle: String?
    }

    /// One row in Trash (FEATURES §4.20).
    enum TrashItem: Identifiable {
        case task(TaskItem)
        case list(TaskList)

        var id: String {
            switch self {
            case .task(let task): "task:\(task.id)"
            case .list(let list): "list:\(list.id)"
            }
        }

        var deletedAt: Date {
            switch self {
            case .task(let task): task.deletedAt ?? .distantPast
            case .list(let list): list.deletedAt ?? .distantPast
            }
        }
    }

    enum FocusSurface: String, Sendable {
        case panel
        case floatingTimer
    }

    /// What the live card's big number counts with Pomodoros on: the task's estimate with the sprint as a chip,
    /// or the sprint itself in pink (DESIGN_SYSTEM §10.2).
    enum SprintDisplay: String, CaseIterable, Sendable {
        case task
        case sprint
    }

    /// The screen edge the Focus Panel docks to.
    enum PanelSide: String, CaseIterable, Sendable {
        case left
        case right
    }

    /// Every list in sidebar order, including those in Trash or archived; they keep their place for a restore.
    private(set) var allLists: [TaskList] {
        didSet { persist(.lists(from: oldValue, to: allLists)) }
    }
    /// The lists in the sidebar and every picker.
    var lists: [TaskList] { allLists.filter(\.isActive) }
    /// Tasks of lists in Trash or archived, off the Board until their list comes back.
    private var shelved: [TaskItem] {
        didSet { persist(.tasks(from: oldValue, to: shelved)) }
    }
    /// Deleted tasks for 30 days (FEATURES §4.20), newest first in the Trash view. Apart from `tasks`, so
    /// nothing on the Board, in search or in reminders has to skip them.
    private(set) var trash: [TaskItem] {
        didSet { persist(.tasks(from: oldValue, to: trash)) }
    }
    /// Archived tasks, kept for Reports.
    private var archived: [TaskItem] {
        didSet { persist(.tasks(from: oldValue, to: archived)) }
    }
    /// The Trash view is in place of the Board.
    var isShowingTrash = false
    private(set) var tasks: [TaskItem] {
        didSet {
            persist(.tasks(from: oldValue, to: tasks))
            syncTimesUp()
            scheduleReminderSync()
        }
    }
    /// nil shows All lists.
    var selectedListID: String?
    private(set) var focus = Focus() {
        // Whatever moved the break's end, the break-over alert follows it.
        didSet { if focus.breakEndsAt != oldValue.breakEndsAt { syncBreakEnd() } }
    }
    var isPomodoroOn = true {
        didSet {
            syncSprint()
            savePreference(isPomodoroOn ? "1" : "0", for: Preference.pomodoro)
        }
    }
    // Quick Settings (DESIGN_SYSTEM §13.8); the Settings window edits the same values.
    var sprintLength: TimeInterval = 25 * 60 {
        didSet {
            syncSprint()
            savePreference("\(Int(sprintLength))", for: Preference.sprintSeconds)
        }
    }
    var sprintDisplay = SprintDisplay.task {
        didSet { savePreference(sprintDisplay.rawValue, for: Preference.sprintDisplay) }
    }
    /// Also the length of a break started by hand while Pomodoros are on (FEATURES §4.11).
    var breakLength: TimeInterval = 5 * 60 {
        didSet { savePreference("\(Int(breakLength))", for: Preference.breakSeconds) }
    }
    var panelSide = PanelSide.right {
        didSet { savePreference(panelSide.rawValue, for: Preference.panelSide) }
    }
    /// When the workday ends, in minutes after midnight; the header measures the plan against it.
    var workdayEnd = 18 * 60 {
        didSet { savePreference("\(workdayEnd)", for: Preference.workdayEnd) }
    }
    var playsSounds = true {
        didSet { savePreference(playsSounds ? "1" : "0", for: Preference.sounds) }
    }
    /// The Settings window's other values (FEATURES §4.18); each change writes only the keys that moved.
    var settings = AppSettings() {
        didSet {
            for (key, value) in settings.changes(since: oldValue) { savePreference(value, for: key) }
            if settings.weekStart != oldValue.weekStart { expandRecurrences() }
            if settings.timedAlerts != oldValue.timedAlerts
                || settings.timedAlertInterval != oldValue.timedAlertInterval
            {
                syncTimedAlert()
            }
        }
    }
    /// Where Focus mode shows while the Home window steps aside (FEATURES §4.8, §4.9); nil shows Home.
    var focusSurface: FocusSurface?
    /// Bumped by ⌘⇧P; the floating timer ripples each time it changes.
    private(set) var locatorPings = 0
    /// Bumped by ⌘⇧B and the menu bar's Open Komodo; the menu bar item reopens Home each time it changes.
    private(set) var homeRequests = 0
    /// Bumped when the date changes under a running app (midnight, a time zone change, waking from sleep).
    private(set) var dayChanges = 0
    /// Global shortcuts another app already holds; Settings marks them "Used by another app".
    var shortcutConflicts: Set<GlobalShortcut> = []
    /// The Settings window's page (DESIGN_SYSTEM §13.15).
    var settingsSection = SettingsSection.general
    /// Bumped by every way into Settings; the window controller brings the window up each time it changes.
    private(set) var settingsRequests = 0
    /// ⌘F's search and command palette (DESIGN_SYSTEM §13.7).
    var isPaletteOpen = false
    /// The task open in the inspector (DESIGN_SYSTEM §13.5); nil when it's closed.
    var inspectedTaskID: String?
    /// The card showing the Schedule popover, whether it was opened from the hover row, ⋯ or right-click.
    var schedulingTaskID: String?
    /// The ⌘⌥T quick add panel (DESIGN_SYSTEM §13.4).
    var isQuickAddOpen = false
    /// The list to return to from All lists.
    private(set) var lastListID: String?
    /// Children of recurring tasks deleted by hand, so expanding the week doesn't bring them back.
    private var dismissedChildren: Set<String> = [] {
        didSet { savePreference(dismissedChildren.sorted().joined(separator: "\n"), for: Preference.dismissedRepeats) }
    }
    let toasts = ToastCenter()
    /// The window's, so ⌘Z and Edit ▸ Undo reach the same restore as the toast's button. Set by `HomeView`.
    weak var undoManager: UndoManager?
    let calendar: Calendar
    private let clock: () -> Date
    private let openURL: (URL) -> Void
    /// Ends the running sprint on time and starts its break (FEATURES §4.10).
    private var sprintEnd: Task<Void, Never>?
    /// Says the break is over when it runs out (FEATURES §4.11).
    private var breakEnd: Task<Void, Never>?
    /// Timed alerts' nudge while the live task runs (FEATURES §4.18).
    private var timedAlert: Task<Void, Never>?
    /// Sound and notifications; set by the app, absent in previews.
    var alerts: FocusAlerts? {
        didSet { scheduleReminderSync() }
    }
    private var heartbeat: Task<Void, Never>?
    /// Time's Up for the running task (DESIGN_SYSTEM §14.2).
    private var timesUpAlert: Task<Void, Never>?
    /// Reminders go to the system a moment after edits settle, so typing a title doesn't resubmit them each key.
    private var reminderSync: Task<Void, Never>?
    /// Where every change is written; nil keeps the board in memory, as previews and captures do.
    let database: AppDatabase?
    /// A restore or Delete all data is loading the new contents, which are already in the file.
    @ObservationIgnored private var isReloading = false
    /// Export zip's spinner (DESIGN_SYSTEM §13.21).
    var isExporting = false
    /// The first-launch sheet over Home (DESIGN_SYSTEM §13.1).
    var isOnboarding = false
    /// Onboarding's last step: the tip pointing at Start, once Today has something in it.
    var showsStartTip = false

    /// Settings kept in the database's `preferences` table.
    enum Preference {
        static let pomodoro = "pomodoro"
        static let sprintSeconds = "sprintSeconds"
        static let breakSeconds = "breakSeconds"
        static let sprintDisplay = "sprintDisplay"
        static let panelSide = "panelSide"
        static let workdayEnd = "workdayEnd"
        static let sounds = "sounds"
        static let dismissedRepeats = "dismissedRepeats"
        // What Focus mode was doing when Komodo quit, and the running session's last sign of life.
        static let liveTask = "liveTask"
        static let liveSurface = "liveSurface"
        static let breakEndsAt = "breakEndsAt"
        static let breakLength = "breakLength"
        static let heartbeat = "heartbeat"
        static let onboarded = "onboarded"
    }

    init(
        lists: [TaskList], tasks: [TaskItem], selectedListID: String?, calendar: Calendar = .current,
        clock: @escaping () -> Date = { Date() }, openURL: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) },
        database: AppDatabase? = nil, preferences: [String: String] = [:], trash: [TaskItem] = [],
        archived: [TaskItem] = [], shelved: [TaskItem] = []
    ) {
        self.allLists = lists
        self.shelved = shelved
        self.tasks = tasks
        self.trash = trash
        self.archived = archived
        self.database = database
        self.selectedListID = selectedListID
        self.lastListID = selectedListID
        self.calendar = calendar
        self.clock = clock
        self.openURL = openURL
        // A sample's open session means a task is already live; a saved one means Komodo stopped without quitting.
        if database != nil {
            let recovered = CrashRecovery.closingOpenSessions(
                in: tasks,
                lastHeartbeat: preferences[Preference.heartbeat].flatMap(Double.init).map(
                    Date.init(timeIntervalSince1970:)))
            self.tasks = recovered.tasks
            // The quit-time state is older than a crash, so it only applies after a clean quit.
            if let interrupted = recovered.interrupted { offerResume(interrupted) } else { restoreFocus(preferences) }
        } else if let live = tasks.first(where: { task in task.sessions.contains { $0.end == nil } }) {
            focus.taskID = live.id
            focus.flowStartedAt = max(0, live.timeTaken(at: clock()) - 25 * 60)
            focus.sprintSince = clock()
        }
        apply(preferences)
        isOnboarding = needsOnboarding(preferences)
        expandRecurrences()
        // Initializers don't run observers, so this week's new repeat copies are written here.
        persist(.tasks(from: tasks, to: self.tasks))
        purgeTrash()
        syncSprint()
        // A break restored from the last quit still says when it's over.
        syncBreakEnd()
    }

    // MARK: Storage

    private func apply(_ preferences: [String: String]) {
        if let value = preferences[Preference.pomodoro] { isPomodoroOn = value == "1" }
        if let value = preferences[Preference.sprintSeconds].flatMap(Double.init) { sprintLength = value }
        if let value = preferences[Preference.breakSeconds].flatMap(Double.init) { breakLength = value }
        if let value = preferences[Preference.sprintDisplay].flatMap(SprintDisplay.init) { sprintDisplay = value }
        if let value = preferences[Preference.panelSide].flatMap(PanelSide.init) { panelSide = value }
        if let value = preferences[Preference.workdayEnd].flatMap(Int.init) { workdayEnd = value }
        if let value = preferences[Preference.sounds] { playsSounds = value == "1" }
        settings = AppSettings(stored: preferences)
        if let value = preferences[Preference.dismissedRepeats], !value.isEmpty {
            dismissedChildren = Set(value.split(separator: "\n").map(String.init))
        }
    }

    /// Writes one change; a failure is logged and shown, and the board carries on in memory.
    func persist(_ change: BoardChange) {
        guard let database, !isReloading, !change.isEmpty else { return }
        do {
            try database.apply(change, at: now)
        } catch {
            reportStorage(error)
        }
    }

    private func savePreference(_ value: String, for key: String) {
        guard let database, !isReloading else { return }
        do {
            try database.setPreference(value, for: key, at: now)
        } catch {
            reportStorage(error)
        }
    }

    private func reportStorage(_ error: any Error) {
        Logger(subsystem: "app.komodo.Komodo", category: "storage").error("Couldn't save: \(error)")
        toasts.show(
            Toast(kind: .error, message: "Couldn't save your changes", detail: "They'll stay until you quit."))
    }

    /// A saved board that hasn't finished onboarding and has nothing in it: a first launch, a quit halfway through
    /// onboarding, or Delete all data. A board that already has tasks never sees it, whatever its preferences say.
    private func needsOnboarding(_ preferences: [String: String]) -> Bool {
        database != nil && preferences[Preference.onboarded] == nil && tasks.isEmpty && trash.isEmpty
            && archived.isEmpty && shelved.isEmpty
    }

    /// Onboarding's Continue or Skip: each line typed on the Today step becomes a Today task, and the Start tip
    /// follows when there's something to start.
    func finishOnboarding(adding lines: [String]) {
        let listID = selectedListID ?? lists.first?.id
        let added = lines.compactMap { addTask($0, to: .today, listID: listID) }
        savePreference("1", for: Preference.onboarded)
        isOnboarding = false
        showsStartTip = !added.isEmpty
    }

    /// After a restore or Delete all data the board starts over from the file: Focus mode ends, open surfaces
    /// close and every setting is read again. Nothing is written back while the new contents load, since the file
    /// already holds them.
    func reload() {
        guard let database else { return }
        let stored: StoredBoard
        do {
            stored = try database.load()
        } catch {
            Logger(subsystem: "app.komodo.Komodo", category: "storage").error("Couldn't reload: \(error)")
            toasts.show(
                Toast(kind: .error, message: "Couldn't open your tasks", detail: "Restart Komodo to try again."))
            return
        }
        let lists = stored.lists.contains(where: \.isActive) ? stored.lists : stored.lists + [Self.firstList]
        isReloading = true
        focus = Focus()
        focusSurface = nil
        inspectedTaskID = nil
        schedulingTaskID = nil
        isShowingTrash = false
        isPaletteOpen = false
        isQuickAddOpen = false
        allLists = lists
        tasks = stored.tasks
        shelved = stored.shelved
        trash = stored.trash.sorted { $0.deletedAt ?? .now > $1.deletedAt ?? .now }
        archived = stored.archived
        selectedListID = self.lists.first?.id
        lastListID = selectedListID
        // Anything the file doesn't mention goes back to its default, as on a first launch.
        isPomodoroOn = true
        sprintLength = 25 * 60
        breakLength = 5 * 60
        sprintDisplay = .task
        panelSide = .right
        workdayEnd = 18 * 60
        playsSounds = true
        dismissedChildren = []
        apply(stored.preferences)
        isOnboarding = needsOnboarding(stored.preferences)
        undoManager?.removeAllActions()
        isReloading = false
        persist(.lists(from: stored.lists, to: lists))
        expandRecurrences()
        syncSprint()
        syncBreakEnd()
        scheduleReminderSync()
    }

    /// Quitting ends the running session, so a relaunch doesn't count the time Komodo was closed.
    func pauseForQuit() {
        if let id = focus.taskID { closeSession(id) }
        savePreference(focus.taskID ?? "", for: Preference.liveTask)
        savePreference(focusSurface?.rawValue ?? "", for: Preference.liveSurface)
        savePreference(focus.breakEndsAt.map { "\($0.timeIntervalSince1970)" } ?? "", for: Preference.breakEndsAt)
        savePreference("\(Int(focus.breakLength))", for: Preference.breakLength)
    }

    /// The task that was live at quit comes back live but paused, in the surface it was in, and a break that
    /// hasn't run out carries on. The Pomodoro count starts over.
    private func restoreFocus(_ preferences: [String: String]) {
        guard let id = preferences[Preference.liveTask],
            let task = tasks.first(where: { $0.id == id }), task.completedAt == nil
        else { return }
        focus.taskID = id
        focus.flowStartedAt = task.timeTaken(at: now)
        focusSurface = preferences[Preference.liveSurface].flatMap(FocusSurface.init)
        if let endsAt = preferences[Preference.breakEndsAt].flatMap(Double.init).map(Date.init(timeIntervalSince1970:)),
            endsAt > now
        {
            focus.breakEndsAt = endsAt
            focus.breakLength = preferences[Preference.breakLength].flatMap(Double.init) ?? 0
        }
    }

    /// After a crash the task stays live but paused, and the toast offers to pick it up again.
    private func offerResume(_ task: TaskItem) {
        focus.taskID = task.id
        focus.flowStartedAt = task.timeTaken(at: now)
        toasts.show(
            Toast(
                kind: .info, message: "Resume \(task.title)?", detail: "Komodo closed unexpectedly.",
                action: .init(title: "Resume") { [weak self] in self?.togglePause() }))
    }

    /// Midnight, a new time zone or a wake: this week's repeat copies are made and the Board moves to the new day
    /// (FEATURES §4.7). A wake on the same day finds nothing new, so repeating it is harmless.
    func dayMayHaveChanged() {
        dayChanges += 1
        purgeTrash()
        expandRecurrences()
        scheduleReminderSync()
    }

    /// Show Komodo: Home comes forward, reopened if it was closed.
    func showHome() { homeRequests += 1 }

    /// ⌘,, the sidebar's Settings, Quick Settings' All settings and the palette: opens Settings on a page.
    func showSettings(_ section: SettingsSection? = nil) {
        if let section { settingsSection = section }
        settingsRequests += 1
    }

    // MARK: Derived

    var now: Date { clock() }
    var today: LocalDate {
        // Reading the counter makes every view that shows the day redraw when it turns over.
        _ = dayChanges
        return LocalDate(now, calendar: calendar)
    }
    var week: WeekRange {
        WeekRange(containing: today, firstWeekday: settings.weekStart.firstWeekday, calendar: calendar)
    }
    var layout: BoardLayout {
        BoardLayout(tasks: tasks, listID: selectedListID, week: week, calendar: calendar)
    }

    func showList(_ id: String?) {
        isShowingTrash = false
        selectedListID = id
        if let id { lastListID = id }
    }

    func showBoard() { showList(lastListID ?? lists.first?.id) }
    var selectedList: TaskList? { lists.first { $0.id == selectedListID } }
    var isFocusing: Bool { focus.taskID != nil || focus.breakEndsAt != nil || focus.celebration != nil }

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

    /// Any list, including one in Trash, so a trashed task can still name where it came from.
    func list(for task: TaskItem) -> TaskList? { allLists.first { $0.id == task.listID } }

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

    /// The current sprint's clock on the wall clock, like `focusClock(for:)`.
    var sprintClock: FocusClock {
        focus.pomodoro.clock(runningSince: focus.sprintSince?.addingTimeInterval(-clockOffset))
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

    /// Moves a task to Trash, with Undo (FEATURES §4.20).
    func delete(_ id: String) {
        guard var removed = takeOff(id) else { return }
        removed.deletedAt = now
        trash.insert(removed, at: 0)
        offerUndo("Task deleted", detail: removed.title) { store in store.restore(removed.id, announces: false) }
    }

    /// The card menu's Archive: the task leaves the Board and search but stays in reports (FEATURES §4.3).
    func archive(_ id: String) {
        guard var removed = takeOff(id) else { return }
        removed.archivedAt = now
        archived.append(removed)
        offerUndo("Task archived", detail: removed.title) { store in
            guard let index = store.archived.firstIndex(where: { $0.id == removed.id }) else { return }
            var task = store.archived.remove(at: index)
            task.archivedAt = nil
            store.putBack(task)
        }
    }

    /// Trash's Restore: the task goes back where it was, with Undo returning it to Trash.
    func restore(_ id: String, announces: Bool = true) {
        guard let index = trash.firstIndex(where: { $0.id == id }) else { return }
        var task = trash.remove(at: index)
        let deletedAt = task.deletedAt
        task.deletedAt = nil
        // A task whose list is archived waits with the list's other tasks rather than showing up alone.
        if list(for: task)?.isActive == false {
            shelved.append(task)
            return
        }
        putBack(task)
        guard announces else { return }
        offerUndo("Restored “\(task.title)”", detail: nil) { store in
            guard var again = store.takeOff(task.id) else { return }
            again.deletedAt = deletedAt
            store.trash.insert(again, at: 0)
        }
    }

    /// Trash's Delete now: gone for good.
    func deleteForever(_ id: String) {
        trash.removeAll { $0.id == id }
    }

    func emptyTrash() {
        for list in allLists where list.deletedAt != nil { deleteListForever(list.id) }
        trash = []
    }

    /// Trash's rows, newest first. A deleted list is one row; tasks it took along are inside it, not beside it.
    var trashItems: [TrashItem] {
        let lists = allLists.filter { $0.deletedAt != nil }
        let listIDs = Set(lists.map(\.id))
        let items = lists.map(TrashItem.list) + trash.filter { !listIDs.contains($0.listID) }.map(TrashItem.task)
        return items.sorted { $0.deletedAt > $1.deletedAt }
    }

    /// Items past their 30 days leave for good; checked at launch and each new day.
    private func purgeTrash() {
        let expired = trash.filter { task in
            task.deletedAt.map { Trash.isExpired(deletedAt: $0, now: now, calendar: calendar) } ?? true
        }
        if !expired.isEmpty { trash.removeAll { expired.contains($0) } }
        for list in allLists {
            if let deletedAt = list.deletedAt, Trash.isExpired(deletedAt: deletedAt, now: now, calendar: calendar) {
                deleteListForever(list.id)
            }
        }
    }

    /// Takes a task off the Board. A live one stops its clock first, so coming back finds it paused rather than
    /// running unseen, and a deleted repeat copy isn't made again.
    private func takeOff(_ id: String) -> TaskItem? {
        if focus.taskID == id {
            closeSession(id)
            focus = Focus()
        }
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = tasks.remove(at: index)
        if inspectedTaskID == id { inspectedTaskID = nil }
        if removed.repeatParentID != nil { dismissedChildren.insert(id) }
        return removed
    }

    private func putBack(_ task: TaskItem) {
        dismissedChildren.remove(task.id)
        if !tasks.contains(where: { $0.id == task.id }) { tasks.append(task) }
    }

    // MARK: Lists (FEATURES §4.1)

    /// A new list goes to the bottom of the sidebar and opens with three empty columns. Nil when the name isn't
    /// valid, which the sheet already prevents.
    @discardableResult
    func createList(name: String, color: ListColor, letter: String?) -> String? {
        guard let name = TaskList.validName(name) else { return nil }
        let list = TaskList(id: UUID().uuidString, name: name, color: color.rawValue, letter: Self.badge(letter))
        allLists.append(list)
        showList(list.id)
        return list.id
    }

    /// Rename and Color & Icon. An empty badge goes back to the name's first letter.
    func updateList(_ id: String, name: String, color: ListColor, letter: String?) {
        guard let name = TaskList.validName(name), let index = allLists.firstIndex(where: { $0.id == id }) else {
            return
        }
        allLists[index].name = name
        allLists[index].color = color.rawValue
        allLists[index].letter = Self.badge(letter) ?? TaskList.defaultLetter(for: name)
    }

    /// Dragging in the sidebar: the list lands just above `beforeID`, or at the bottom.
    func moveList(_ id: String, before beforeID: String?) {
        guard id != beforeID, let index = allLists.firstIndex(where: { $0.id == id }) else { return }
        var reordered = allLists
        let list = reordered.remove(at: index)
        let target = beforeID.flatMap { before in reordered.firstIndex { $0.id == before } } ?? reordered.endIndex
        reordered.insert(list, at: target)
        allLists = reordered
    }

    /// Archive and Delete need another list left, since the Board always adds to one.
    var canRemoveLists: Bool { lists.count > 1 }

    /// Archive: the list and its tasks leave the sidebar, All lists and search, and stay for reports.
    func archiveList(_ id: String) {
        guard canRemoveLists, let index = allLists.firstIndex(where: { $0.id == id && $0.isActive }) else { return }
        shelveTasks(of: id)
        allLists[index].archivedAt = now
        leaveList(id)
        offerUndo("List archived", detail: allLists[index].name) { store in store.bringBackList(id) }
    }

    /// Delete: the list and its tasks wait in Trash for 30 days (FEATURES §4.20).
    func deleteList(_ id: String) {
        guard canRemoveLists, let index = allLists.firstIndex(where: { $0.id == id && $0.isActive }) else { return }
        shelveTasks(of: id)
        allLists[index].deletedAt = now
        leaveList(id)
        offerUndo("List deleted", detail: allLists[index].name) { store in store.bringBackList(id) }
    }

    /// Trash's Restore for a list: it returns to its place in the sidebar with its tasks, with Undo.
    func restoreList(_ id: String) {
        guard let list = allLists.first(where: { $0.id == id }), let deletedAt = list.deletedAt else { return }
        bringBackList(id)
        offerUndo("Restored “\(list.name)”", detail: nil) { store in
            guard let index = store.allLists.firstIndex(where: { $0.id == id }), store.allLists[index].isActive
            else { return }
            store.shelveTasks(of: id)
            store.allLists[index].deletedAt = deletedAt
            store.leaveList(id)
        }
    }

    /// Delete now or 30 days up: the list goes for good with every task that was in it.
    func deleteListForever(_ id: String) {
        shelved.removeAll { $0.listID == id }
        trash.removeAll { $0.listID == id }
        archived.removeAll { $0.listID == id }
        allLists.removeAll { $0.id == id }
    }

    private func bringBackList(_ id: String) {
        guard let index = allLists.firstIndex(where: { $0.id == id }) else { return }
        allLists[index].deletedAt = nil
        allLists[index].archivedAt = nil
        tasks += shelved.filter { $0.listID == id }
        shelved.removeAll { $0.listID == id }
        // Weeks may have turned while it was away.
        expandRecurrences()
    }

    /// Takes a list's tasks off the Board. A live one stops first, as when a task is deleted.
    private func shelveTasks(of listID: String) {
        let leaving = tasks.filter { $0.listID == listID }
        let ids = Set(leaving.map(\.id))
        if let live = focus.taskID, ids.contains(live) {
            closeSession(live)
            focus = Focus()
        }
        if let inspected = inspectedTaskID, ids.contains(inspected) { inspectedTaskID = nil }
        if let scheduling = schedulingTaskID, ids.contains(scheduling) { schedulingTaskID = nil }
        tasks.removeAll { ids.contains($0.id) }
        shelved += leaving
    }

    /// A list on screen that goes away hands over to the first one left.
    private func leaveList(_ id: String) {
        if lastListID == id { lastListID = lists.first?.id }
        if selectedListID == id { selectedListID = lists.first?.id }
    }

    /// One character, a letter or an emoji; nil when nothing was typed.
    private static func badge(_ raw: String?) -> String? {
        raw?.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() }
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

    /// The palette's ⌘↵: this task goes live now, and Focus mode opens if it wasn't already on.
    func startNow(_ id: String) {
        makeLive(id)
        if focusSurface == nil { focusSurface = .panel }
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

    /// Done: completes the live task and celebrates. The next task starts when the celebration ends, so it
    /// never plays over running time.
    func completeLive() {
        guard let id = focus.taskID, let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        closeSession(id)
        tasks[index].completedAt = now
        focus.taskID = nil
        let task = tasks[index]
        if settings.playsSuccessSound, playsSounds { KomodoSound.playSuccess(volume: settings.volume) }
        focus.celebration = Celebration(
            taskID: id, title: task.title,
            message: CelebrationCopy.message(estimate: task.estimate, taken: task.timeTaken(at: now)),
            nextTitle: layout.upNext.first?.title)
        // With the success screen off, Done goes straight to the next task.
        if !settings.showsSuccessScreen { finishCelebration() }
    }

    /// After about 2.5 s, a click or Esc: the next eligible task starts. With only timed tasks left the panel
    /// waits for them; with nothing left the day is won.
    func finishCelebration() {
        guard focus.celebration != nil else { return }
        focus.celebration = nil
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

    /// A break by hand: the Pomodoro break while sprints are on, the default break otherwise (FEATURES §4.11).
    func takeBreak() {
        guard let id = focus.taskID else { return }
        closeSession(id)
        let length = isPomodoroOn ? breakLength : settings.defaultBreakLength
        focus.breakEndsAt = now.addingTimeInterval(length)
        focus.breakLength = length
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
        focus.celebration = nil
        if settings.opensLinksOnStart { tasks.first { $0.id == id }?.linksToOpen.forEach(openURL) }
        openSession(id)
        focus.flowStartedAt = tasks.first { $0.id == id }?.timeTaken(at: now) ?? 0
    }

    private func openSession(_ id: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }),
            tasks[index].sessions.allSatisfy({ $0.end != nil })
        else { return }
        tasks[index].sessions.append(WorkSession(start: now))
        focus.sprintSince = now
        syncSprint()
    }

    private func closeSession(_ id: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }),
            let open = tasks[index].sessions.lastIndex(where: { $0.end == nil })
        else { return }
        tasks[index].sessions[open].end = now
        if let since = focus.sprintSince {
            focus.pomodoro.record(now.timeIntervalSince(since))
            focus.sprintSince = nil
        }
        syncSprint()
    }

    /// Schedules the end of the running sprint, or cancels it when nothing runs or Pomodoros are off.
    private func syncSprint() {
        syncHeartbeat()
        syncTimedAlert()
        syncTimesUp()
        sprintEnd?.cancel()
        sprintEnd = nil
        guard isPomodoroOn, focus.taskID != nil, focus.breakEndsAt == nil, let since = focus.sprintSince else { return }
        let remaining = focus.pomodoro.remaining(of: sprintLength, at: now, runningSince: since)
        sprintEnd = Task { [weak self] in
            guard (try? await Task.sleep(for: .seconds(remaining))) != nil else { return }
            self?.endSprint()
        }
    }

    /// The sprint ran its length: the task pauses and keeps its time, and a break starts. Nothing resumes on its
    /// own afterwards (FEATURES §4.11).
    private func endSprint() {
        guard let id = focus.taskID, focus.sprintSince != nil else { return }
        closeSession(id)
        let finished = focus.pomodoro.number
        focus.pomodoro.finishSprint()
        focus.breakEndsAt = now.addingTimeInterval(breakLength)
        focus.breakLength = breakLength
        alerts?.sprintEnded(
            sprint: finished, of: PomodoroCycle.sprintsPerSet, breakLength: breakLength,
            task: tasks.first { $0.id == id }?.title ?? "Your task")
        play(.glass)
    }

    /// Every Komodo sound goes through here, so Quick Settings' Sounds switch and the volume cover them all.
    func play(_ sound: KomodoSound) {
        if playsSounds { sound.play(volume: settings.volume) }
    }

    /// Every sprint or pause passes through `syncSprint`, so the nudge restarts its interval with each resume.
    private func syncTimedAlert() {
        timedAlert?.cancel()
        timedAlert = nil
        guard settings.timedAlerts, focus.breakEndsAt == nil, focus.sprintSince != nil else { return }
        let interval = settings.timedAlertInterval
        timedAlert = Task { [weak self] in
            while (try? await Task.sleep(for: .seconds(interval))) != nil {
                guard let self else { return }
                play(settings.timedAlertSound)
                if settings.pulsesTimer { locatorPings += 1 }
            }
        }
    }

    /// Every 30 s while a session runs, so a crash can close it where it stopped (ARCHITECTURE §4.3).
    private func syncHeartbeat() {
        heartbeat?.cancel()
        heartbeat = nil
        guard database != nil, focus.sprintSince != nil else { return }
        heartbeat = Task { [weak self] in
            repeat {
                guard let self else { return }
                savePreference("\(now.timeIntervalSince1970)", for: Preference.heartbeat)
            } while (try? await Task.sleep(for: .seconds(30))) != nil
        }
    }

    /// The running task's estimate runs out: a sound, and a notification when the panel isn't there to say it.
    private func syncTimesUp() {
        timesUpAlert?.cancel()
        timesUpAlert = nil
        guard let live = liveTask, focusClock(for: live).isRunning, let estimate = live.estimate else { return }
        let remaining = estimate - live.timeTaken(at: now)
        guard remaining > 0 else { return }
        timesUpAlert = Task { [weak self] in
            guard (try? await Task.sleep(for: .seconds(remaining))) != nil, let self else { return }
            play(.glass)
            if focusSurface != .panel { alerts?.timesUp(task: live.title, estimate: estimate) }
        }
    }

    /// Only a saved board reminds; previews and captures hold sample tasks in memory.
    private func scheduleReminderSync() {
        guard database != nil, let alerts else { return }
        reminderSync?.cancel()
        reminderSync = Task { [weak self] in
            guard (try? await Task.sleep(for: .seconds(1))) != nil, let self else { return }
            alerts.syncReminders(Reminders.upcoming(in: tasks, after: now, calendar: calendar), calendar: calendar)
        }
    }

    private func syncBreakEnd() {
        breakEnd?.cancel()
        breakEnd = nil
        guard let endsAt = focus.breakEndsAt, endsAt > now else { return }
        breakEnd = Task { [weak self] in
            guard let self, (try? await Task.sleep(for: .seconds(endsAt.timeIntervalSince(now)))) != nil else { return }
            let task = focus.taskID.flatMap { id in tasks.first { $0.id == id }?.title } ?? "your task"
            alerts?.breakOver(task: task)
            play(.glass)
        }
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

    private func offerUndo(_ message: String, detail: String?, restore: @escaping @MainActor (BoardStore) -> Void) {
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
