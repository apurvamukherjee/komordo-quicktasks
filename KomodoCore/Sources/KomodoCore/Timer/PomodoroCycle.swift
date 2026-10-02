import Foundation

/// Where the Pomodoro cycle stands (FEATURES §4.10, §4.11): which of the four sprints is running and how much work
/// it holds. Work carries across tasks, since a sprint is time focused, not time on one task. Only a sprint that
/// runs its full length moves the count on; a break taken by hand resumes the same sprint.
public struct PomodoroCycle: Sendable, Equatable {
    public static let sprintsPerSet = 4

    /// 1…4.
    public private(set) var number = 1
    /// Work in this sprint from sessions that have ended; the open one is added by `clock(runningSince:)`.
    public private(set) var worked: TimeInterval = 0

    public init() {}

    /// A cycle saved at quit, kept within 1…4 and never negative.
    public init(number: Int, worked: TimeInterval) {
        self.number = min(max(number, 1), Self.sprintsPerSet)
        self.worked = max(0, worked)
    }

    /// `number worked`, as a preference keeps it.
    public var saved: String { "\(number) \(Int(worked))" }

    public init?(saved: String) {
        let parts = saved.split(separator: " ").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        self.init(number: Int(parts[0]), worked: parts[1])
    }

    public mutating func record(_ work: TimeInterval) { worked += max(0, work) }

    /// The sprint ran its length: the next one starts from zero, and the fifth wraps back to the first.
    public mutating func finishSprint() {
        number = number % Self.sprintsPerSet + 1
        worked = 0
    }

    public func clock(runningSince: Date?) -> FocusClock { FocusClock(accumulated: worked, runningSince: runningSince) }

    /// How long until the sprint ends, never below zero.
    public func remaining(of length: TimeInterval, at date: Date, runningSince: Date?) -> TimeInterval {
        max(0, length - clock(runningSince: runningSince).elapsed(at: date))
    }
}
