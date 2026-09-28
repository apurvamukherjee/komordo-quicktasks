import Foundation

/// The end-of-queue numbers (FEATURES §4.8, DESIGN_SYSTEM §13.11): how many tasks finished early, on time or
/// late against their estimates, and the share that landed on the estimate or better.
public struct DaySummary: Sendable, Equatable {
    public var early = 0
    public var onTime = 0
    public var late = 0

    /// Within 10% of the estimate either way counts as on time, as in the Punctuality report (FEATURES §4.14).
    public static let onTimeTolerance = 0.1

    /// Tasks without an estimate have nothing to be early or late against, so they're left out.
    public init(doneToday: [TaskItem], now: Date) {
        for task in doneToday {
            guard let estimate = task.estimate, estimate > 0 else { continue }
            let difference = (task.timeTaken(at: now) - estimate) / estimate
            if difference < -Self.onTimeTolerance {
                early += 1
            } else if difference > Self.onTimeTolerance {
                late += 1
            } else {
                onTime += 1
            }
        }
    }

    public var measured: Int { early + onTime + late }

    /// Early or on time, out of every task with an estimate; nil when none had one.
    public var onEstimate: Double? {
        measured == 0 ? nil : Double(early + onTime) / Double(measured)
    }
}
