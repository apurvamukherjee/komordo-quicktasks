import Foundation

/// Durations as DESIGN_SYSTEM §3 writes them: `2hr 30min`, `1hr`, `30min`.
public enum DurationFormat {
    /// Rounds to the nearest minute, and shows anything under a minute as `0min` so an estimate never reads blank.
    public static func short(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int((interval / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        switch (hours, minutes) {
        case (0, let minutes): return "\(minutes)min"
        case (let hours, 0): return "\(hours)hr"
        default: return "\(hours)hr \(minutes)min"
        }
    }
}
