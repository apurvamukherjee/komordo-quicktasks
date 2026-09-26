import Foundation

/// A project or area, such as "Work" (FEATURES §4.1).
public struct TaskList: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    /// One of the eight list colors (DESIGN_SYSTEM §2.4), stored by name as in the schema.
    public var color: String
    /// The badge letter; defaults to the name's first letter.
    public var letter: String

    public init(id: String, name: String, color: String, letter: String? = nil) {
        self.id = id
        self.name = name
        self.color = color
        self.letter = letter ?? name.first.map { String($0).uppercased() } ?? "?"
    }
}
