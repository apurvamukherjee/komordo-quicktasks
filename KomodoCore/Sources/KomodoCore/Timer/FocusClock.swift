import Foundation

/// Elapsed time is recomputed from wall-clock anchors on every read, never by counting ticks,
/// so a view that skips frames or a Mac that sleeps can't make the timer drift (ARCHITECTURE §4.3).
public struct FocusClock: Equatable, Sendable {
    public var accumulated: TimeInterval
    public var runningSince: Date?

    public init(accumulated: TimeInterval = 0, runningSince: Date? = nil) {
        self.accumulated = accumulated
        self.runningSince = runningSince
    }

    public var isRunning: Bool { runningSince != nil }

    public func elapsed(at date: Date) -> TimeInterval {
        guard let runningSince else { return accumulated }
        return accumulated + max(0, date.timeIntervalSince(runningSince))
    }
}
