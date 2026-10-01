import Foundation

/// Days and times as people say them, so the Assistant's brains can pass words through rather than do date
/// arithmetic, which a small on-device model gets wrong.
public enum DayPhrase {
    /// "today", "tomorrow", "fri", "next monday", "next week", "in 3 days", or "2026-10-12". A weekday means its
    /// next occurrence, today included.
    public static func day(_ phrase: String, today: LocalDate, calendar: Calendar) -> LocalDate? {
        let text = phrase.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "by ", with: "").replacingOccurrences(of: "on ", with: "")
        if let date = LocalDate(iso: text) { return date }
        switch text {
        case "today", "tonight": return today
        case "tomorrow", "tmrw": return today.adding(days: 1, calendar: calendar)
        case "next week": return nextWeekday(2, after: today.adding(days: 1, calendar: calendar), calendar: calendar)
        default: break
        }
        let words = text.split(separator: " ").map(String.init)
        if words.count == 3, words[0] == "in", let count = Int(words[1]), words[2].hasPrefix("day") {
            return today.adding(days: count, calendar: calendar)
        }
        let isNext = words.first == "next"
        guard let name = isNext ? words.dropFirst().first : words.first, let weekday = weekday(name) else {
            return nil
        }
        let start = isNext ? today.adding(days: 1, calendar: calendar) : today
        return nextWeekday(weekday, after: start, calendar: calendar)
    }

    /// Minutes after midnight: "14:30", "7:00", "7am", "7:30 pm", "noon". A bare "7" is 7 AM.
    public static func minute(_ phrase: String) -> Int? {
        var text = phrase.lowercased().replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ".", with: "")
        if text == "noon" { return 12 * 60 }
        if text == "midnight" { return 0 }
        var offset = 0
        if text.hasSuffix("pm") || text.hasSuffix("am") {
            offset = text.hasSuffix("pm") ? 12 * 60 : 0
            text.removeLast(2)
        }
        let parts = text.split(separator: ":").map { Int($0) }
        guard let hourValue = parts.first, var hour = hourValue, parts.count <= 2 else { return nil }
        let minute = parts.count == 2 ? (parts[1] ?? -1) : 0
        guard (0..<60).contains(minute) else { return nil }
        if offset > 0 || phrase.lowercased().contains("am") {
            guard (1...12).contains(hour) else { return nil }
            hour %= 12
        }
        let total = hour * 60 + minute + offset
        return (0..<24 * 60).contains(total) ? total : nil
    }

    private static func weekday(_ name: String) -> Int? {
        let names = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        return names.firstIndex { name.hasPrefix($0) }.map { $0 + 1 }
    }

    /// The first day on or after `start` that falls on `weekday` (1 is Sunday, as `Calendar` counts).
    private static func nextWeekday(_ weekday: Int, after start: LocalDate, calendar: Calendar) -> LocalDate {
        let current = calendar.component(.weekday, from: start.startOfDay(in: calendar))
        return start.adding(days: (weekday - current + 7) % 7, calendar: calendar)
    }
}
