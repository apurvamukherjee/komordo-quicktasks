import Foundation

/// Reads a trailing estimate out of a new task's title (FEATURES §4.3): `Email campaign 2hr 15min` becomes
/// "Email campaign" with 2h15m. Only a match at the very end counts, so "Read 2 chapters" is left alone.
public enum EstimateParser {
    public struct Result: Equatable, Sendable {
        public var title: String
        public var estimate: TimeInterval?
    }

    public static func parse(_ input: String) -> Result {
        // Regex isn't Sendable, so the patterns live here rather than in static storage.
        // Hours with optional minutes (2h, 2 hrs, 1.5h, 1h30, 2hr 15min), minutes alone (90m, 45 min), or H:MM.
        let hoursAndMinutes =
            #/(?i)\s(\d+(?:\.\d+)?)\s*(?:h|hr|hrs|hour|hours)(?:\s*(\d{1,2})\s*(?:m|min|mins|minute|minutes)?)?$/#
        let minutesOnly = #/(?i)\s(\d+)\s*(?:m|min|mins|minute|minutes)$/#
        let clock = #/\s(\d{1,2}):(\d{2})$/#
        let text = input.trimmingCharacters(in: .whitespaces)
        // A leading space lets the patterns require a word boundary before the number.
        let padded = " " + text

        if let match = padded.firstMatch(of: hoursAndMinutes), let hours = Double(match.1) {
            let minutes = match.2.flatMap { Int($0) } ?? 0
            return finish(padded, match.range, hours * 3600 + Double(minutes) * 60, original: text)
        }
        if let match = padded.firstMatch(of: minutesOnly), let minutes = Int(match.1) {
            return finish(padded, match.range, Double(minutes) * 60, original: text)
        }
        if let match = padded.firstMatch(of: clock), let hours = Int(match.1), let minutes = Int(match.2),
            minutes < 60
        {
            return finish(padded, match.range, Double(hours * 3600 + minutes * 60), original: text)
        }
        return Result(title: text, estimate: nil)
    }

    private static func finish(
        _ padded: String, _ range: Range<String.Index>, _ seconds: TimeInterval, original: String
    ) -> Result {
        let title = String(padded[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        // A title that is only a duration keeps its text; there's nothing left to name the task.
        guard !title.isEmpty, seconds > 0 else { return Result(title: original, estimate: nil) }
        return Result(title: title, estimate: seconds)
    }
}
