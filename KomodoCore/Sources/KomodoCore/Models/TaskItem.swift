import Foundation

/// The column a task sits in when it has no date (the schema's `bucket`).
public enum Bucket: String, CaseIterable, Sendable {
    case backlog
    case week
    case today
}

public struct Subtask: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var isDone: Bool

    public init(id: String, title: String, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}

/// One continuous stretch of work. An open session has no end yet.
public struct WorkSession: Hashable, Sendable {
    public var start: Date
    public var end: Date?

    public init(start: Date, end: Date? = nil) {
        self.start = start
        self.end = end
    }

    public func duration(until now: Date) -> TimeInterval {
        max(0, (end ?? now).timeIntervalSince(start))
    }
}

public enum TaskSource: String, Sendable {
    case gmail
    case calendar
}

public struct TaskItem: Identifiable, Hashable, Sendable {
    public var id: String
    public var listID: String
    public var title: String
    public var bucket: Bucket
    /// Priority within its column; lower comes first. Moves write a value between the neighbours.
    public var rank: Double
    public var estimate: TimeInterval?
    /// Plain text, for search, cards and export.
    public var notes: String?
    /// The same notes with formatting, as RTF for the editor (ARCHITECTURE §4 `notes_rtf`).
    public var notesRTF: Data?
    /// Open the notes' links when the task goes live (the schema's `auto_open_links`).
    public var opensLinks: Bool
    public var scheduledDate: LocalDate?
    /// Minutes after local midnight; nil means all day.
    public var scheduledMinute: Int?
    public var dueDate: LocalDate?
    /// Set on a recurring parent (FEATURES §4.7), with the day the rule counts from.
    public var repeatRule: RepeatRule?
    public var repeatStart: LocalDate?
    /// Set on the children a parent makes.
    public var repeatParentID: String?
    /// Remind at the scheduled time (DESIGN_SYSTEM §13.6). Only meaningful with a time.
    public var remindsAtStart: Bool
    public var completedAt: Date?
    /// Moved to Trash (FEATURES §4.20); gone for good 30 days later.
    public var deletedAt: Date?
    /// Hidden everywhere except reports (FEATURES §4.3).
    public var archivedAt: Date?
    public var subtasks: [Subtask]
    public var source: TaskSource?
    /// Who and what the task came from, such as `Apurva · “Re: Design review”`, and where to open it.
    public var sourceTitle: String?
    public var sourceURL: URL?
    public var sessions: [WorkSession]
    /// nil for tasks made before these were recorded.
    public var createdAt: Date?
    public var editedAt: Date?

    public init(
        id: String, listID: String, title: String, bucket: Bucket, rank: Double, estimate: TimeInterval? = nil,
        notes: String? = nil, notesRTF: Data? = nil, opensLinks: Bool = true, scheduledDate: LocalDate? = nil,
        scheduledMinute: Int? = nil, dueDate: LocalDate? = nil, repeatRule: RepeatRule? = nil,
        repeatStart: LocalDate? = nil, repeatParentID: String? = nil, remindsAtStart: Bool = true,
        completedAt: Date? = nil, deletedAt: Date? = nil, archivedAt: Date? = nil, subtasks: [Subtask] = [],
        source: TaskSource? = nil, sourceTitle: String? = nil, sourceURL: URL? = nil, sessions: [WorkSession] = [],
        createdAt: Date? = nil, editedAt: Date? = nil
    ) {
        self.id = id
        self.listID = listID
        self.title = title
        self.bucket = bucket
        self.rank = rank
        self.estimate = estimate
        self.notes = notes
        self.notesRTF = notesRTF
        self.opensLinks = opensLinks
        self.scheduledDate = scheduledDate
        self.scheduledMinute = scheduledMinute
        self.dueDate = dueDate
        self.repeatRule = repeatRule
        self.repeatStart = repeatStart
        self.repeatParentID = repeatParentID
        self.remindsAtStart = remindsAtStart
        self.deletedAt = deletedAt
        self.archivedAt = archivedAt
        self.completedAt = completedAt
        self.subtasks = subtasks
        self.source = source
        self.sourceTitle = sourceTitle
        self.sourceURL = sourceURL
        self.sessions = sessions
        self.createdAt = createdAt
        self.editedAt = editedAt
    }

    public var isDone: Bool { completedAt != nil }
    public var hasNotes: Bool { !(notes ?? "").isEmpty }
    public var subtasksDone: Int { subtasks.filter(\.isDone).count }

    /// The web links in the notes, in order and without repeats. Found in the text rather than stored, so the
    /// Links chip and auto-open always agree with what the notes say (FEATURES §4.5).
    public var links: [URL] { NoteLinks.find(in: notes ?? "") }

    /// What opens in the browser when the task goes live: at most five links, none when the toggle is off.
    public var linksToOpen: [URL] { opensLinks ? Array(links.prefix(Self.maxLinksToOpen)) : [] }
    public static let maxLinksToOpen = 5

    /// Summed from sessions and never stored (ARCHITECTURE §5).
    public func timeTaken(at now: Date) -> TimeInterval {
        sessions.reduce(0) { $0 + $1.duration(until: now) }
    }

    /// Edits time taken (FEATURES §4.3) by changing sessions, since time taken is never stored. More time adds a
    /// session ending now; less trims the latest sessions first. Does nothing while a session is open, because
    /// the clock is still writing to it.
    public mutating func setTimeTaken(_ target: TimeInterval, at now: Date) {
        guard sessions.allSatisfy({ $0.end != nil }) else { return }
        var excess = timeTaken(at: now) - max(0, target)
        if excess < 0 {
            sessions.append(WorkSession(start: now.addingTimeInterval(excess), end: now))
            return
        }
        while excess > 0, let last = sessions.indices.last {
            let length = sessions[last].duration(until: now)
            if length > excess {
                sessions[last].end = sessions[last].start.addingTimeInterval(length - excess)
                return
            }
            sessions.removeLast()
            excess -= length
        }
    }

    /// What's left of the estimate; zero once it's used up or when there is no estimate.
    public func remaining(at now: Date) -> TimeInterval {
        guard let estimate else { return 0 }
        return max(0, estimate - timeTaken(at: now))
    }

    /// When a task with a time starts; nil for tasks without a day or a time.
    public func scheduledStart(calendar: Calendar) -> Date? {
        guard let day = scheduledDate, let minute = scheduledMinute else { return nil }
        return calendar.date(byAdding: .minute, value: minute, to: day.startOfDay(in: calendar))
    }

    /// The column a scheduled task derives from its date (FEATURES §4.2): today or earlier → Today,
    /// this week → This week, later → Backlog. Unscheduled tasks stay where they were put.
    public func column(in week: WeekRange) -> Bucket {
        guard let date = scheduledDate else { return bucket }
        if date <= week.today { return .today }
        if date <= week.end { return .week }
        return .backlog
    }
}
