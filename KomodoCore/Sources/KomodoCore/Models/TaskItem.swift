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
    public var notes: String?
    public var scheduledDate: LocalDate?
    /// Minutes after local midnight; nil means all day.
    public var scheduledMinute: Int?
    public var dueDate: LocalDate?
    /// A readable rule until recurrences land, e.g. "Every Friday".
    public var repeatSummary: String?
    public var completedAt: Date?
    public var subtasks: [Subtask]
    public var linkCount: Int
    public var source: TaskSource?
    public var sessions: [WorkSession]

    public init(
        id: String, listID: String, title: String, bucket: Bucket, rank: Double, estimate: TimeInterval? = nil,
        notes: String? = nil, scheduledDate: LocalDate? = nil, scheduledMinute: Int? = nil, dueDate: LocalDate? = nil,
        repeatSummary: String? = nil, completedAt: Date? = nil, subtasks: [Subtask] = [], linkCount: Int = 0,
        source: TaskSource? = nil, sessions: [WorkSession] = []
    ) {
        self.id = id
        self.listID = listID
        self.title = title
        self.bucket = bucket
        self.rank = rank
        self.estimate = estimate
        self.notes = notes
        self.scheduledDate = scheduledDate
        self.scheduledMinute = scheduledMinute
        self.dueDate = dueDate
        self.repeatSummary = repeatSummary
        self.completedAt = completedAt
        self.subtasks = subtasks
        self.linkCount = linkCount
        self.source = source
        self.sessions = sessions
    }

    public var isDone: Bool { completedAt != nil }
    public var hasNotes: Bool { !(notes ?? "").isEmpty }
    public var subtasksDone: Int { subtasks.filter(\.isDone).count }

    /// Summed from sessions and never stored (ARCHITECTURE §5).
    public func timeTaken(at now: Date) -> TimeInterval {
        sessions.reduce(0) { $0 + $1.duration(until: now) }
    }

    /// What's left of the estimate; zero once it's used up or when there is no estimate.
    public func remaining(at now: Date) -> TimeInterval {
        guard let estimate else { return 0 }
        return max(0, estimate - timeTaken(at: now))
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
