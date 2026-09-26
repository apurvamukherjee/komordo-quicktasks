import Foundation

/// Timer strings from DESIGN_SYSTEM §3: `MM:SS` below an hour, `H:MM:SS` past it,
/// and a leading `+` for overtime.
public enum TimerFormat {
    /// Negative values are overtime, so callers can pass `estimate - elapsed` directly.
    public static func clock(_ totalSeconds: Int) -> String {
        let sign = totalSeconds < 0 ? "+" : ""
        let seconds = abs(totalSeconds)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return sign + "\(hours):" + twoDigits(minutes) + ":" + twoDigits(secs)
        }
        return sign + twoDigits(minutes) + ":" + twoDigits(secs)
    }

    /// Countdowns show a second as remaining until it has fully passed, so 00:00 appears exactly at the estimate.
    public static func remaining(estimate: TimeInterval, elapsed: TimeInterval) -> String {
        let left = estimate - elapsed
        let whole = left >= 0 ? Int(left.rounded(.up)) : Int(left.rounded(.towardZero))
        return clock(whole)
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
