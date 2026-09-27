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
