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
            estimate: task.estimate ?? 3_600, flowStartedAt: focus.flowStartedAt, linksOpened: task.linksToOpen.count,
            subtasks: task.subtasks.isEmpty ? nil : .init(done: task.subtasksDone, total: task.subtasks.count))
    }

    /// "3:00" and "PM" for the scheduled card's time column.
    func timeParts(for task: TaskItem) -> (time: String, period: String) {
        guard let minute = task.scheduledMinute else { return ("All", "day") }
        let date = (task.scheduledDate ?? today).startOfDay(in: calendar).addingTimeInterval(TimeInterval(minute * 60))
        let time = date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
        let period = date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated))).components(separatedBy: " ")
            .last
        return (time, period ?? "")
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
        return task.repeatSummary.map { .repeats($0) }
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
