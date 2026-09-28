import KomodoCore
import SwiftUI

/// Turns core tasks into what the card components display: badge colors, chip wording, progress.
extension BoardStore {
    func cardModel(for task: TaskItem) -> TaskCardModel {
        let list = list(for: task)
        let taken = task.timeTaken(at: now)
        return TaskCardModel(
            id: task.id, title: task.title, listLetter: list?.letter ?? "?",
            listColor: list.flatMap { ListColor(rawValue: $0.color) } ?? .lime, estimate: task.estimate,
            timeTaken: taken,
            subtasks: task.subtasks.isEmpty ? nil : .init(done: task.subtasksDone, total: task.subtasks.count),
            hasNotes: task.hasNotes, linkCount: task.links.count, timing: timing(for: task),
            repeatText: task.repeatParentID == nil ? nil : repeatSummary(for: task),
            hasReminder: task.scheduledDate != nil && task.scheduledMinute != nil && task.remindsAtStart,
            source: task.source.map { $0 == .gmail ? .gmail : .calendar }, outcome: outcome(for: task),
            // Parked cards stay compact until there's something to track, as on the canvas.
            showsProgress: task.estimate != nil
                && (taken > 0 || !task.subtasks.isEmpty || task.hasNotes || task.links.count > 0))
    }

    func liveModel(for task: TaskItem) -> LiveTaskModel {
        let list = list(for: task)
        return LiveTaskModel(
            title: task.title, listLetter: list?.letter ?? "?",
            listColor: list.flatMap { ListColor(rawValue: $0.color) } ?? .lime,
            source: task.source.map { $0 == .gmail ? "From Gmail" : "From Calendar" },
            estimate: task.estimate ?? 3_600, flowStartedAt: focus.flowStartedAt,
            sprint: isPomodoroOn
                ? .init(
                    number: focus.pomodoro.number, count: PomodoroCycle.sprintsPerSet, length: sprintLength,
                    clock: sprintClock, isHero: sprintDisplay == .sprint)
                : nil,
            linksOpened: task.linksToOpen.count,
            subtasks: task.subtasks.isEmpty ? nil : .init(done: task.subtasksDone, total: task.subtasks.count))
    }

    /// The card menu (FEATURES §4.3): Schedule · Subtasks · Notes · Duplicate · Move to list · Archive · Delete.
    /// Subtasks and Notes open the inspector, where both live.
    func cardMenu(for task: TaskItem) -> [[CardAction]] {
        let otherLists = lists.filter { $0.id != task.listID }.map { list in
            // Letter squares stand in for the canvas's list badges; native menus draw symbols in one color.
            CardAction(label: list.name, symbol: "\(list.letter.lowercased()).square.fill") {
                self.update(task.id) { $0.listID = list.id }
            }
        }
        return [
            [
                CardAction(label: "Schedule", symbol: "calendar") { self.schedulingTaskID = task.id },
                CardAction(label: "Subtasks", symbol: "checklist") { self.inspect(task.id) },
                CardAction(label: "Notes", symbol: "note.text") { self.inspect(task.id) },
            ],
            [
                CardAction(
                    label: "Duplicate", symbol: "plus.square.on.square",
                    shortcut: KeyboardShortcut("d", modifiers: .command)
                ) { self.duplicate(task.id) },
                CardAction(label: "Move to list", symbol: "folder", menu: [otherLists]),
            ],
            [
                // Archive lands with Trash (FEATURES §4.20).
                CardAction(label: "Archive", symbol: "archivebox", isEnabled: false),
                CardAction(
                    label: "Delete", symbol: "trash", isDestructive: true,
                    shortcut: KeyboardShortcut(.delete, modifiers: .command)
                ) { self.delete(task.id) },
            ],
        ]
    }

    /// "3:00" and "PM" for the scheduled card's time column.
    func timeParts(for task: TaskItem) -> (time: String, period: String) {
        guard let minute = task.scheduledMinute else { return ("All", "day") }
        let date = (task.scheduledDate ?? today).startOfDay(in: calendar).addingTimeInterval(TimeInterval(minute * 60))
        // Split the locale's own short time, since formatters put a narrow no-break space before "PM" and
        // formatting the hour without it zero-pads in some locales. 24-hour locales have no period.
        let parts = date.formatted(date: .omitted, time: .shortened).split(whereSeparator: \.isWhitespace)
        return (parts.first.map(String.init) ?? "", parts.dropFirst().joined(separator: " "))
    }

    func startLabel(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    private func timing(for task: TaskItem) -> TaskCardModel.Timing? {
        if let date = task.scheduledDate {
            let label = scheduleLabel(date: date, minute: task.scheduledMinute)
            return date < today ? .overdue("Overdue · \(label)") : .scheduled(label)
        }
        if let due = task.dueDate {
            let text = due.startOfDay(in: calendar).formatted(.dateTime.month(.abbreviated).day())
            return .due("Due \(text)")
        }
        return task.isRecurringParent ? repeatSummary(for: task).map { .repeats($0) } : nil
    }

    /// "Thu, Oct 1 · 2:30 PM", "Today · 2:00 PM" or "Sat, Oct 10 · all day", for the inspector and the popover.
    func scheduleText(date: LocalDate, minute: Int?) -> String {
        let day = date.startOfDay(in: calendar)
        let dayText = date == today ? "Today" : day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        guard let minute else { return "\(dayText) · all day" }
        let time = day.addingTimeInterval(TimeInterval(minute * 60)).formatted(date: .omitted, time: .shortened)
        return "\(dayText) · \(time)"
    }

    /// "Sun 10:00 AM" within the week, "Oct 12" beyond it, the time alone for today.
    private func scheduleLabel(date: LocalDate, minute: Int?) -> String {
        let day = date.startOfDay(in: calendar)
        let time = minute.map { day.addingTimeInterval(TimeInterval($0 * 60)).formatted(.dateTime.hour().minute()) }
        if date == today { return time ?? "Today" }
        let dayText =
            date <= week.end && date >= week.start
            ? day.formatted(.dateTime.weekday(.abbreviated)) : day.formatted(.dateTime.month(.abbreviated).day())
        return [dayText, time].compactMap { $0 }.joined(separator: " ")
    }

    private func outcome(for task: TaskItem) -> TaskCardModel.Outcome? {
        guard task.isDone else { return nil }
        guard let estimate = task.estimate else { return .onTime }
        let difference = estimate - task.timeTaken(at: now)
        // Within a minute either way reads as on time.
        if difference >= 60 { return .early(difference) }
        if difference <= -60 { return .over(-difference) }
        return .onTime
    }
}
