import Foundation
import Testing

@testable import KomodoCore

struct TaskListTests {
    @Test(
        arguments: [
            ("  Growth ", "Growth"), ("", nil), ("   ", nil),
            (String(repeating: "a", count: 60), String(repeating: "a", count: 60)),
            (String(repeating: "a", count: 61), nil),
        ] as [(String, String?)])
    func namesAreTrimmedAndOneToSixtyCharacters(raw: String, saved: String?) {
        #expect(TaskList.validName(raw) == saved)
    }

    @Test func theBadgeDefaultsToTheFirstLetter() {
        #expect(TaskList(id: "g", name: " growth", color: "amber").letter == "G")
        #expect(TaskList(id: "g", name: "Growth", color: "amber", letter: "🌱").letter == "🌱")
    }

    @Test func trashedAndArchivedListsAreInactive() {
        let list = TaskList(id: "g", name: "Growth", color: "amber")
        #expect(list.isActive)
        #expect(!TaskList(id: "g", name: "Growth", color: "amber", deletedAt: .now).isActive)
        #expect(!TaskList(id: "g", name: "Growth", color: "amber", archivedAt: .now).isActive)
    }
}
