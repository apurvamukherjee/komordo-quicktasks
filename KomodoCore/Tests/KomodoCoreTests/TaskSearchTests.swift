import Foundation
import Testing

@testable import KomodoCore

struct TaskSearchTests {
    private func task(
        _ id: String, _ title: String, notes: String? = nil, subtasks: [String] = [], done: Bool = false
    ) -> TaskItem {
        TaskItem(
            id: id, listID: "work", title: title, bucket: .today, rank: 0, notes: notes,
            completedAt: done ? Date(timeIntervalSinceReferenceDate: 0) : nil,
            subtasks: subtasks.map { Subtask(id: $0, title: $0) })
    }

    @Test func titleMatchesComeBeforeNotesAndDoneComesLast() {
        let tasks = [
            task("done", "Design review: portfolio site", done: true),
            task("notes", "Q4 engineering roadmap", notes: "Agree the scope after the design review."),
            task("title", "Design review prep with Apurva"),
        ]
        #expect(TaskSearch.hits(for: "design rev", in: tasks).map(\.taskID) == ["title", "notes", "done"])
    }

    @Test func aNotesMatchCarriesASnippet() {
        let hit = TaskSearch.hits(
            for: "design", in: [task("notes", "Roadmap", notes: "Agree the scope after the design review.")]
        ).first
        #expect(hit?.place == .notes(snippet: "…scope after the design review."))
    }

    @Test func subtasksAreSearchedAndCaseAndAccentsDontMatter() {
        let hit = TaskSearch.hits(for: "resume", in: [task("s", "Hiring", subtasks: ["Read Résumés"])]).first
        #expect(hit?.place == .subtask(title: "Read Résumés"))
    }

    @Test func aBlankQueryFindsNothing() {
        #expect(TaskSearch.hits(for: "  ", in: [task("t", "Anything")]).isEmpty)
    }
}
