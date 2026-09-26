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

    /// The duration field shows `HH:MM` (DESIGN_SYSTEM §10.6).
    public static func hoursMinutes(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int((interval / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return (hours < 10 ? "0" : "") + "\(hours):" + (minutes < 10 ? "0" : "") + "\(minutes)"
    }

    /// Reads what people type into the duration field: `1:30`, `01:30`, or bare minutes like `45`.
    /// Returns nil for anything else, including minutes past 59, so the field can show its invalid state.
    public static func parseHoursMinutes(_ text: String) -> TimeInterval? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        switch parts.count {
        case 1:
            guard let minutes = Int(parts[0]), minutes >= 0 else { return nil }
            return TimeInterval(minutes * 60)
        case 2:
            guard let hours = Int(parts[0]), let minutes = Int(parts[1]), hours >= 0, (0..<60).contains(minutes),
                parts[1].count == 2
            else { return nil }
            return TimeInterval(hours * 3600 + minutes * 60)
        default:
            return nil
        }
    }
}
