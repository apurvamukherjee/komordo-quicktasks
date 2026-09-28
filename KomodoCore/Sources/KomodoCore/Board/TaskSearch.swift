import Foundation

/// ⌘F search (FEATURES §4.16): titles, notes and subtasks across every list, Done included. A title match ranks
/// first; a match only in the notes or a subtask carries a snippet showing where it was found.
public enum TaskSearch {
    public struct Hit: Sendable, Equatable {
        public enum Place: Sendable, Equatable {
            case title
            /// "…scope after the design review" — a little of what comes before the match, then the rest.
            case notes(snippet: String)
            case subtask(title: String)
        }

        public var taskID: String
        public var place: Place
    }

    /// How much of the notes to keep before the match, so the snippet reads as a phrase.
    static let lead = 18

    /// Open tasks before done ones and title matches before the rest, then by title.
    public static func hits(for query: String, in tasks: [TaskItem]) -> [Hit] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return [] }
        let found: [(task: TaskItem, hit: Hit)] = tasks.compactMap { task in
            place(of: needle, in: task).map { (task, Hit(taskID: task.id, place: $0)) }
        }
        return found.sorted { lhs, rhs in
            if lhs.task.isDone != rhs.task.isDone { return !lhs.task.isDone }
            if (lhs.hit.place == .title) != (rhs.hit.place == .title) { return lhs.hit.place == .title }
            return lhs.task.title.localizedStandardCompare(rhs.task.title) == .orderedAscending
        }
        .map(\.hit)
    }

    static func place(of needle: String, in task: TaskItem) -> Hit.Place? {
        if find(needle, in: task.title) != nil { return .title }
        if let notes = task.notes?.replacingOccurrences(of: "\n", with: " "), let range = find(needle, in: notes) {
            return .notes(snippet: snippet(notes, around: range))
        }
        if let subtask = task.subtasks.first(where: { find(needle, in: $0.title) != nil }) {
            return .subtask(title: subtask.title)
        }
        return nil
    }

    /// Case- and accent-blind, as the views highlight it.
    public static func find(_ needle: String, in text: String) -> Range<String.Index>? {
        text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive])
    }

    /// Starts at a word boundary a little before the match, so it never opens mid-word.
    static func snippet(_ notes: String, around range: Range<String.Index>) -> String {
        guard let early = notes.index(range.lowerBound, offsetBy: -lead, limitedBy: notes.startIndex),
            early > notes.startIndex
        else { return notes.trimmingCharacters(in: .whitespaces) }
        let start = notes[early..<range.lowerBound].firstIndex(of: " ").map { notes.index(after: $0) } ?? early
        return "…" + notes[start...].trimmingCharacters(in: .whitespaces)
    }
}
