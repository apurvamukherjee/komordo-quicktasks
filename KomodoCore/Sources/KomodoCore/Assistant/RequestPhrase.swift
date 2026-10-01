import Foundation

/// One phrase of what the user wrote, such as "finish the deck by Fri (3h)", with the day, time and length it
/// says. The Assistant's tasks take these from their own phrase rather than from the model, which mixes them up
/// between tasks.
struct RequestPhrase: Equatable {
    var text: String
    var day: String?
    var minute: Int?
    var minutes: Int?

    /// Splits on commas, semicolons, new lines and " and ".
    static func split(_ request: String) -> [RequestPhrase] {
        request.lowercased()
            .replacingOccurrences(of: " and ", with: ",")
            .split(whereSeparator: { ",;\n".contains($0) })
            .map { RequestPhrase(String($0).trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.text.isEmpty }
    }

    init(_ text: String) {
        self.text = text
        day = Self.day(in: text)
        minute = Self.minute(in: text)
        minutes = Self.minutes(in: text)
    }

    /// The phrase sharing the most words with `title`; nil when none shares one.
    static func best(for title: String, in phrases: [RequestPhrase]) -> RequestPhrase? {
        let words = Set(
            title.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count >= 3 })
        let scored = phrases.map { phrase in
            (phrase, words.filter { phrase.text.contains($0) }.count)
        }
        guard let top = scored.max(by: { $0.1 < $1.1 }), top.1 > 0 else { return nil }
        return top.0
    }

    private static func day(in text: String) -> String? {
        if let range = text.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) { return String(text[range]) }
        if text.contains("next week") { return "next week" }
        if let range = text.range(of: #"\bin \d+ days?\b"#, options: .regularExpression) { return String(text[range]) }
        let tokens = text.split { !$0.isLetter }.map(String.init)
        for (index, token) in tokens.enumerated() {
            if ["today", "tonight", "tomorrow", "tmrw"].contains(token) { return token }
            let weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
            if weekdays.contains(where: { $0 == token || ($0.hasPrefix(token) && token.count == 3) }) {
                return index > 0 && tokens[index - 1] == "next" ? "next " + token : token
            }
        }
        return nil
    }

    /// "at 7", "7am", "7:30 pm", "14:30", "noon" or "midnight"; a bare number only after "at".
    private static func minute(in text: String) -> Int? {
        if text.contains("noon") { return 12 * 60 }
        if text.contains("midnight") { return 0 }
        let patterns = [
            #"\b\d{1,2}(:\d{2})?\s*(am|pm)\b"#, #"\b\d{1,2}:\d{2}\b"#, #"\bat \d{1,2}(:\d{2})?\b"#,
        ]
        for pattern in patterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                return DayPhrase.minute(text[range].replacingOccurrences(of: "at ", with: ""))
            }
        }
        return nil
    }

    /// "1h", "(3h)", "45 min", "1.5 hours".
    private static func minutes(in text: String) -> Int? {
        guard
            let range = text.range(
                of: #"\d+(\.\d+)?\s*(hours|hour|hrs|hr|h|minutes|minute|mins|min|m)\b"#, options: .regularExpression)
        else { return nil }
        let match = text[range]
        guard let number = Double(match.prefix { $0.isNumber || $0 == "." }) else { return nil }
        let isHours = match.contains("h")
        return Int((isHours ? number * 60 : number).rounded())
    }
}
