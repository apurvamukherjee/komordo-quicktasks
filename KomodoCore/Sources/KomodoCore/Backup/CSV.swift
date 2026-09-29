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
}
