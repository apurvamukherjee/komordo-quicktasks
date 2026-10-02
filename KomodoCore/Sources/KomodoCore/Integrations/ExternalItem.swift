import Foundation

/// A provider's task in Komodo's terms, whichever provider it came from, so the sync rules are written once.
public struct ExternalItem: Equatable, Sendable {
    public var id: String
    public var title: String
    public var notes: String?
    /// The day it's planned for, and the time when there is one.
    public var date: LocalDate?
    public var minute: Int?
    public var dueDate: LocalDate?
    public var estimate: TimeInterval?
    public var isDone: Bool
    public var isDeleted: Bool
    /// Assigned to the user, or to nobody (FEATURES §5 "Only my items").
    public var isMine: Bool
    public var updatedAt: Date?
    /// Where to open it at the provider.
    public var url: URL?

    public init(
        id: String, title: String, notes: String? = nil, date: LocalDate? = nil, minute: Int? = nil,
        dueDate: LocalDate? = nil, estimate: TimeInterval? = nil, isDone: Bool = false, isDeleted: Bool = false,
        isMine: Bool = true, updatedAt: Date? = nil, url: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.date = date
        self.minute = minute
        self.dueDate = dueDate
        self.estimate = estimate
        self.isDone = isDone
        self.isDeleted = isDeleted
        self.isMine = isMine
        self.updatedAt = updatedAt
        self.url = url
    }

    /// The fields that sync both ways, in the order a snapshot keeps them.
    public enum Field: Int, CaseIterable, Sendable {
        case title, notes, date, minute, dueDate, estimate, done
    }

    /// Which fields differ between two snapshots, so a push sends only what was edited: rewriting an untouched due
    /// date would drop a provider's repeat rule, for one.
    public static func changes(from old: String, to new: String) -> Set<Field> {
        let before = old.split(separator: "\u{1F}", omittingEmptySubsequences: false)
        let after = new.split(separator: "\u{1F}", omittingEmptySubsequences: false)
        return Set(
            Field.allCases.filter { field in
                before.dropFirst(field.rawValue).first != after.dropFirst(field.rawValue).first
            })
    }

    /// The fields that sync both ways, as one string a link can keep and compare.
    public var snapshot: String {
        Self.snapshot(
            title: title, notes: notes, date: date, minute: minute, dueDate: dueDate, estimate: estimate, isDone: isDone
        )
    }

    public static func snapshot(of task: TaskItem) -> String {
        snapshot(
            title: task.title, notes: task.notes, date: task.scheduledDate, minute: task.scheduledMinute,
            dueDate: task.dueDate, estimate: task.estimate, isDone: task.isDone)
    }

    private static func snapshot(
        title: String, notes: String?, date: LocalDate?, minute: Int?, dueDate: LocalDate?, estimate: TimeInterval?,
        isDone: Bool
    ) -> String {
        // Whole minutes, since that's all a provider keeps; seconds left over would read as an edit forever. An
        // undated task's estimate stays out, since Todoist only keeps a duration beside a due date: it would never
        // agree, and each pull would clear it.
        let minutes = date == nil ? nil : estimate.map { String(Int(($0 / 60).rounded())) }
        let parts = [
            title, notes ?? "", date?.description ?? "", date == nil ? "" : minute.map(String.init) ?? "",
            dueDate?.description ?? "", minutes ?? "", isDone ? "1" : "0",
        ]
        return parts.joined(separator: "\u{1F}")
    }
}
