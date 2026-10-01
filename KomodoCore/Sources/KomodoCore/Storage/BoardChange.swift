import Foundation

/// What to write after the board changed in memory: the tasks and lists that are new or different, and the ones
/// that are gone. The store keeps whole arrays; this turns two of them into the few rows that need writing.
public struct BoardChange: Equatable, Sendable {
    public var savedTasks: [TaskItem] = []
    public var deletedTaskIDs: [String] = []
    /// Every list in order when any of them changed, since positions shift together.
    public var savedLists: [TaskList] = []
    public var deletedListIDs: [String] = []
    public var savedBreaks: [BreakSession] = []
    public var deletedBreakIDs: [String] = []

    public init() {}

    /// Posted by `komodo-mcp` after it writes, so the running app reloads what changed (ARCHITECTURE §10).
    public static let darwinNotification = "app.komodo.db-changed"

    public var isEmpty: Bool {
        savedTasks.isEmpty && deletedTaskIDs.isEmpty && savedLists.isEmpty && deletedListIDs.isEmpty
            && savedBreaks.isEmpty && deletedBreakIDs.isEmpty
    }

    public static func breaks(from old: [BreakSession], to new: [BreakSession]) -> BoardChange {
        let before = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        let after = Set(new.map(\.id))
        var change = BoardChange()
        change.savedBreaks = new.filter { before[$0.id] != $0 }
        change.deletedBreakIDs = old.map(\.id).filter { !after.contains($0) }
        return change
    }

    public static func tasks(from old: [TaskItem], to new: [TaskItem]) -> BoardChange {
        let before = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        let after = Set(new.map(\.id))
        var change = BoardChange()
        change.savedTasks = new.filter { before[$0.id] != $0 }
        change.deletedTaskIDs = old.map(\.id).filter { !after.contains($0) }
        return change
    }

    public static func lists(from old: [TaskList], to new: [TaskList]) -> BoardChange {
        var change = BoardChange()
        guard old != new else { return change }
        let after = Set(new.map(\.id))
        change.savedLists = new
        change.deletedListIDs = old.map(\.id).filter { !after.contains($0) }
        return change
    }
}
