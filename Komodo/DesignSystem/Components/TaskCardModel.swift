import KomodoCore
import SwiftUI

/// What a task card displays. Views take this instead of the database model so every card state can be
/// previewed with plain sample data.
struct TaskCardModel: Identifiable, Sendable {
    enum Timing: Sendable {
        case scheduled(String)
        case due(String)
        case repeats(String)
        case overdue(String)
    }

    enum Outcome: Sendable {
        case early(TimeInterval)
        case onTime
        case over(TimeInterval)
    }

    struct Subtasks: Sendable {
        var done: Int
        var total: Int
    }

    var id: String
    var title: String
    var listLetter: String
    var listColor: ListColor
    var estimate: TimeInterval?
    var timeTaken: TimeInterval = 0
    var subtasks: Subtasks?
    var hasNotes = false
    var linkCount = 0
    var timing: Timing?
    var source: SourceBadge.Source?
    /// Set once the task is done; drives the check disc and the result chip.
    var outcome: Outcome?
    /// Parked and repeating tasks hide the footer until they're worked on, as on the canvas.
    var showsProgress = true

    var isDone: Bool { outcome != nil }
    var isOverdue: Bool {
        if case .overdue = timing { return true }
        return false
    }

    var progress: Double {
        guard let estimate, estimate > 0 else { return 0 }
        return min(1, timeTaken / estimate)
    }

    var timeTakenLabel: String { TimerFormat.clock(Int(timeTaken)) }
}

/// One chip's content, derived from the model in the order the canvas uses: when, then how long, then extras.
struct TaskChip: Identifiable {
    var text: String
    var tint: Chip.Tint
    var icon: String?

    var id: String { text }
}

extension TaskCardModel {
    func chips(includingSubtasks: Bool) -> [TaskChip] {
        var chips: [TaskChip] = []
        switch timing {
        case .scheduled(let text): chips.append(TaskChip(text: text, tint: .blue, icon: "calendar"))
        case .due(let text): chips.append(TaskChip(text: text, tint: .amber, icon: "flag"))
        case .repeats(let text): chips.append(TaskChip(text: text, tint: .violet, icon: "repeat"))
        case .overdue(let text): chips.append(TaskChip(text: text, tint: .red, icon: "clock"))
        case nil: break
        }
        if let estimate {
            chips.append(TaskChip(text: DurationFormat.short(estimate), tint: .neutral, icon: "clock"))
        }
        if includingSubtasks, let subtasks {
            chips.append(TaskChip(text: "\(subtasks.done)/\(subtasks.total)", tint: .neutral, icon: "checklist"))
        }
        if hasNotes { chips.append(TaskChip(text: "Notes", tint: .neutral, icon: "note.text")) }
        if linkCount > 0 {
            chips.append(
                TaskChip(text: linkCount == 1 ? "1 link" : "\(linkCount) links", tint: .neutral, icon: "link"))
        }
        return chips
    }

    var outcomeChip: TaskChip? {
        switch outcome {
        case .early(let margin): TaskChip(text: DurationFormat.short(margin) + " early", tint: .green)
        case .onTime: TaskChip(text: "On time", tint: .blue)
        case .over(let margin): TaskChip(text: DurationFormat.short(margin) + " over", tint: .amber)
        case nil: nil
        }
    }
}

enum TaskCardSamples {
    static let roadmap = TaskCardModel(
        id: "roadmap", title: "Q4 engineering roadmap", listLetter: "W", listColor: .lime, estimate: 10_800,
        subtasks: .init(done: 0, total: 5), hasNotes: true)
    static let wireframes = TaskCardModel(
        id: "wireframes", title: "Wireframes: floating timer pill", listLetter: "W", listColor: .lime,
        estimate: 7_200, timeTaken: 1_080, subtasks: .init(done: 1, total: 3), timing: .scheduled("Sun 10:00 AM"))
    static let visa = TaskCardModel(
        id: "visa", title: "Submit visa form", listLetter: "P", listColor: .teal, estimate: 1_800,
        timing: .due("Due Oct 10"), source: .gmail, showsProgress: false)
    static let weeklyReview = TaskCardModel(
        id: "weekly", title: "Weekly review", listLetter: "P", listColor: .teal, estimate: 2_700,
        timing: .repeats("Every Friday"), showsProgress: false)
    static let reviewAccounts = TaskCardModel(
        id: "accounts", title: "Review accounts", listLetter: "W", listColor: .lime, estimate: 9_000,
        subtasks: .init(done: 0, total: 3), hasNotes: true)
    static let doneEarly = TaskCardModel(
        id: "done", title: "Review accounts", listLetter: "W", listColor: .lime, estimate: 9_000,
        timeTaken: 8_280, outcome: .early(720))
    static let overdue = TaskCardModel(
        id: "bank", title: "Call the bank", listLetter: "P", listColor: .teal, timing: .overdue("9:00 AM"),
        showsProgress: false)
    static let dataDetector = TaskCardModel(
        id: "detector", title: "Wire NSDataDetector date parsing", listLetter: "W", listColor: .lime,
        estimate: 5_400, timeTaken: 1_800, subtasks: .init(done: 3, total: 4))
}
