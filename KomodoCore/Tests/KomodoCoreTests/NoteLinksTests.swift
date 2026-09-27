import Foundation
import Testing

@testable import KomodoCore

struct NoteLinksTests {
    @Test func findsWebLinksInOrder() {
        let links = NoteLinks.find(in: "Figma: https://figma.com/file/abc then http://example.com/spec.")
        #expect(links.map(\.absoluteString) == ["https://figma.com/file/abc", "http://example.com/spec"])
    }

    @Test func skipsOtherSchemesAndRepeats() {
        let links = NoteLinks.find(
            in: "mailto:apurva@example.com ftp://files.example.com https://a.com https://a.com")
        #expect(links.map(\.absoluteString) == ["https://a.com"])
    }

    @Test func emptyNotesHaveNoLinks() {
        #expect(NoteLinks.find(in: "").isEmpty)
        #expect(NoteLinks.find(in: "Growth plan, feedback.").isEmpty)
    }
}

struct LinksToOpenTests {
    private func task(notes: String, opensLinks: Bool = true) -> TaskItem {
        TaskItem(id: "t", listID: "work", title: "t", bucket: .today, rank: 0, notes: notes, opensLinks: opensLinks)
    }

    @Test func opensAtMostFive() {
        let notes = (1...7).map { "https://example.com/\($0)" }.joined(separator: " ")
        #expect(task(notes: notes).linksToOpen.count == 5)
        #expect(task(notes: notes).links.count == 7)
    }

    @Test func opensNothingWhenTurnedOff() {
        #expect(task(notes: "https://figma.com/file/abc", opensLinks: false).linksToOpen.isEmpty)
    }
}
