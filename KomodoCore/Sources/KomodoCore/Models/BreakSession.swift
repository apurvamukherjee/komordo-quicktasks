import Foundation

/// A break taken in Focus mode, kept for Reports' Breaks series and the Sessions log (FEATURES §4.15).
public struct BreakSession: Identifiable, Hashable, Sendable {
    public var id: String
    public var start: Date
    /// When it ended, or is due to while it runs; Skip and +2 min move it.
    public var end: Date
    /// The task it paused, if any.
    public var taskID: String?

    public init(id: String, start: Date, end: Date, taskID: String? = nil) {
        self.id = id
        self.start = start
        self.end = end
        self.taskID = taskID
    }

    public var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
}
