import Foundation

/// A project or area, such as "Work" (FEATURES §4.1).
public struct TaskList: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    /// One of the eight list colors (DESIGN_SYSTEM §2.4), stored by name as in the schema.
    public var color: String
    /// The badge: the name's first letter by default, or an emoji.
    public var letter: String
    /// In Trash since then, with its tasks (FEATURES §4.20).
    public var deletedAt: Date?
    /// Hidden with its tasks everywhere except reports.
    public var archivedAt: Date?

    public init(
        id: String, name: String, color: String, letter: String? = nil, deletedAt: Date? = nil,
        archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.letter = letter ?? Self.defaultLetter(for: name)
        self.deletedAt = deletedAt
        self.archivedAt = archivedAt
    }

    /// Shown in the sidebar and the pickers: neither in Trash nor archived.
    public var isActive: Bool { deletedAt == nil && archivedAt == nil }

    public static let nameLimit = 60

    /// The name as it's saved: trimmed, and nil when it's empty or longer than 60 characters.
    public static func validName(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return (1...nameLimit).contains(name.count) ? name : nil
    }

    public static func defaultLetter(for name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "?"
    }
}
