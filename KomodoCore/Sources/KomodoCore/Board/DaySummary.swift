import Foundation

/// The end-of-queue numbers (FEATURES §4.8, DESIGN_SYSTEM §13.11): how many tasks finished early, on time or
/// late against their estimates, and the share that landed on the estimate or better.
public struct DaySummary: Sendable, Equatable {
    public var early = 0
    public var onTime = 0
    public var late = 0

    /// Within 10% of the estimate either way counts as on time, as in the Punctuality report (FEATURES §4.14).
    public static let onTimeTolerance = 0.1

    /// How one finished task landed against its estimate.
    public enum Result: Sendable {
        case early, onTime, late
    }

    /// Tasks without an estimate have nothing to be early or late against, so they're left out.
    public init(doneToday: [TaskItem], now: Date) {
        for task in doneToday {
            switch Self.result(of: task, now: now) {
            case .early: early += 1
            case .onTime: onTime += 1
            case .late: late += 1
            case nil: break
            }
        }
    }

    /// nil without an estimate.
    public static func result(of task: TaskItem, now: Date) -> Result? {
        guard let estimate = task.estimate, estimate > 0 else { return nil }
        let difference = (task.timeTaken(at: now) - estimate) / estimate
        if difference < -onTimeTolerance { return .early }
        if difference > onTimeTolerance { return .late }
        return .onTime
    }

    /// Tasks finished early or on time in a row, counting back from the latest, for the celebration's "3 in a row
    /// today". A late finish ends the run; a task without an estimate neither counts nor ends it.
    public static func onEstimateRun(_ doneToday: [TaskItem], now: Date) -> Int {
        var count = 0
        for task in doneToday.sorted(by: { ($0.completedAt ?? now) > ($1.completedAt ?? now) }) {
            switch result(of: task, now: now) {
            case .early, .onTime: count += 1
            case .late: return count
            case nil: continue
            }
        }
        return count
    }

    public var measured: Int { early + onTime + late }

    /// Early or on time, out of every task with an estimate; nil when none had one.
    public var onEstimate: Double? {
        measured == 0 ? nil : Double(early + onTime) / Double(measured)
    }
}
