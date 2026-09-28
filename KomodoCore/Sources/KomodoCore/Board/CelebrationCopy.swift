import Foundation

/// The line a celebration says about how the task went against its estimate (DESIGN_SYSTEM §7).
public enum CelebrationCopy {
    /// Early, on time (within 10%, as `DaySummary` counts it) or over, e.g. "Nailed it. 12min early."
    /// A task without an estimate has nothing to be early or late against.
    public static func message(estimate: TimeInterval?, taken: TimeInterval) -> String {
        guard let estimate, estimate > 0 else { return "Done." }
        let difference = taken - estimate
        if difference < -estimate * DaySummary.onTimeTolerance {
            return "Nailed it. \(DurationFormat.short(-difference)) early."
        }
        if difference > estimate * DaySummary.onTimeTolerance {
            return "Done. \(DurationFormat.short(difference)) over, still counts."
        }
        return "Done. Right on time."
    }
}
