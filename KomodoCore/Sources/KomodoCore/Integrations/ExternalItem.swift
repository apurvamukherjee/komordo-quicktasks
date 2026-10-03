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
    /// The provider moves a repeating item to its next date when it's completed, instead of keeping it done.
    public var repeats: Bool
    public var updatedAt: Date?
    /// Where to open it at the provider.
    public var url: URL?
    /// The column its status maps to, for an undated item; nil leaves it in Backlog.
    public var bucket: Bucket?
    /// Nil for a provider without subtasks, so a task's own subtasks stay.
    public var subtasks: [Subtask]?

    public init(
        id: String, title: String, notes: String? = nil, date: LocalDate? = nil, minute: Int? = nil,
        dueDate: LocalDate? = nil, estimate: TimeInterval? = nil, isDone: Bool = false, isDeleted: Bool = false,
        isMine: Bool = true, repeats: Bool = false, updatedAt: Date? = nil, url: URL? = nil, bucket: Bucket? = nil,
        subtasks: [Subtask]? = nil
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
        self.repeats = repeats
        self.updatedAt = updatedAt
        self.url = url
        self.bucket = bucket
        self.subtasks = subtasks
    }

    /// The fields that sync both ways, in the order a snapshot keeps them.
    public enum Field: Int, CaseIterable, Sendable {
        case title, notes, date, minute, dueDate, estimate, done, column, subtasks
    }

    /// What one provider keeps of a task.
    public struct Shape: Equatable, Sendable {
        public var fields: Set<Field>
        /// Todoist only keeps a duration beside a due date, so an undated task's estimate stays out: it would
        /// never agree, and each pull would clear it.
        public var estimateNeedsDate: Bool

        public init(fields: Set<Field>, estimateNeedsDate: Bool = false) {
            self.fields = fields
            self.estimateNeedsDate = estimateNeedsDate
        }

        /// Todoist's: everything but statuses and subtasks.
        public static let todoist = Shape(
            fields: [.title, .notes, .date, .minute, .dueDate, .estimate, .done], estimateNeedsDate: true)
    }

    /// Which fields differ between two snapshots, so a push sends only what was edited: rewriting an untouched due
    /// date would drop a provider's repeat rule, for one. A part an older snapshot didn't have reads as empty.
    public static func changes(from old: String, to new: String) -> Set<Field> {
        let before = old.split(separator: "\u{1F}", omittingEmptySubsequences: false)
        let after = new.split(separator: "\u{1F}", omittingEmptySubsequences: false)
        return Set(
            Field.allCases.filter { field in
                (before.dropFirst(field.rawValue).first ?? "") != (after.dropFirst(field.rawValue).first ?? "")
            })
    }

    /// Whether a snapshot was taken of a finished item.
    public static func isDone(snapshot: String) -> Bool {
        snapshot.split(separator: "\u{1F}", omittingEmptySubsequences: false).dropFirst(Field.done.rawValue).first
            == "1"
    }

    /// The fields that sync both ways, as one string a link can keep and compare.
    public var snapshot: String { snapshot(.todoist) }

    public func snapshot(_ shape: Shape) -> String {
        Self.snapshot(
            title: title, notes: notes, date: date, minute: minute, dueDate: dueDate, estimate: estimate,
            isDone: isDone, bucket: bucket ?? .backlog, subtasks: subtasks ?? [], shape: shape)
    }

    public static func snapshot(of task: TaskItem, _ shape: Shape = .todoist) -> String {
        snapshot(
            title: task.title, notes: task.notes, date: task.scheduledDate, minute: task.scheduledMinute,
            dueDate: task.dueDate, estimate: task.estimate, isDone: task.isDone, bucket: task.bucket,
            subtasks: task.subtasks, shape: shape)
    }

    private static func snapshot(
        title: String, notes: String?, date: LocalDate?, minute: Int?, dueDate: LocalDate?, estimate: TimeInterval?,
        isDone: Bool, bucket: Bucket, subtasks: [Subtask], shape: Shape
    ) -> String {
        let has = shape.fields.contains
        // Whole minutes, since that's all a provider keeps; seconds left over would read as an edit forever.
        let minutes = shape.estimateNeedsDate && date == nil ? nil : estimate.map { String(Int(($0 / 60).rounded())) }
        // A column only places an open, undated task; anywhere else the date or Done decides.
        let column = date == nil && !isDone ? bucket.rawValue : ""
        var parts = [
            title, has(.notes) ? notes ?? "" : "", has(.date) ? date?.description ?? "" : "",
            has(.minute) && date != nil ? minute.map(String.init) ?? "" : "",
            has(.dueDate) ? dueDate?.description ?? "" : "", has(.estimate) ? minutes ?? "" : "", isDone ? "1" : "0",
            has(.column) ? column : "",
            has(.subtasks) ? subtasks.map { ($0.isDone ? "x" : "-") + $0.title }.joined(separator: "\u{1E}") : "",
        ]
        // Trailing empty parts are left off, so Todoist's links read the same as before there were more fields.
        while parts.last == "" { parts.removeLast() }
        return parts.joined(separator: "\u{1F}")
    }
}

extension ExternalItem {
    /// `2026-10-01T09:30:00.000000Z`, as every provider writes times. The fraction is dropped first, since the
    /// formatter only reads milliseconds.
    static func instant(_ text: String) -> Date? {
        let whole = text.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return ISO8601DateFormatter().date(from: whole)
    }

    /// The day an instant falls on here, and its minute after midnight.
    static func schedule(at instant: Date, calendar: Calendar) -> (day: LocalDate, minute: Int) {
        let parts = calendar.dateComponents([.hour, .minute], from: instant)
        return (LocalDate(instant, calendar: calendar), (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
    }

    /// A day and minute here as the UTC instant providers take: `2026-10-02T13:00:00Z`.
    static func instantText(day: LocalDate, minute: Int, calendar: Calendar) -> String {
        let instant = day.startOfDay(in: calendar).addingTimeInterval(TimeInterval(minute * 60))
        return ISO8601DateFormatter().string(from: instant)
    }
}
