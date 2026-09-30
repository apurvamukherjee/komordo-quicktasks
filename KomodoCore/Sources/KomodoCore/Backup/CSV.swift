import Foundation

/// RFC 4180 lines for the backup's `tasks.csv` and `sessions.csv`, which open in any spreadsheet.
public enum CSV {
    /// Quotes a field only when it has a comma, a quote or a line break, doubling any quote inside.
    public static func field(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// A header or row followed by CRLF, as the RFC and Excel expect.
    public static func line(_ fields: [String]) -> String {
        fields.map(field).joined(separator: ",") + "\r\n"
    }

    public static func document(header: [String], rows: [[String]]) -> String {
        ([header] + rows).map(line).joined()
    }

    /// Local time as `2026-09-26 14:05`, which spreadsheets read as a date.
    public static func timestamp(_ seconds: Double?, calendar: Calendar) -> String {
        guard let seconds else { return "" }
        let parts = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: Date(timeIntervalSince1970: seconds))
        return String(
            format: "%04d-%02d-%02d %02d:%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0, parts.hour ?? 0,
            parts.minute ?? 0)
    }

    /// Minutes with one decimal, blank when unknown.
    public static func minutes(_ seconds: Double?) -> String {
        seconds.map { String(format: "%.1f", $0 / 60) } ?? ""
    }
}
