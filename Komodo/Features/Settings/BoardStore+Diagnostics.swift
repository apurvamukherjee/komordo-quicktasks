import AppKit
import KomodoCore
import OSLog
import UniformTypeIdentifiers

extension BoardStore {
    /// About's and Help's Save Diagnostics…: version, macOS, counts, settings and this run's Komodo log in a text
    /// file to attach to a bug report (DESIGN_SYSTEM §13.15). Log lines carry errors, never task titles or notes.
    func saveDiagnostics() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Komodo Diagnostics.txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let lines =
            [
                "Komodo \(SettingsAboutPage.version)",
                "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
                "Lists: \(lists.count)",
                "Tasks: \(tasks.count)",
            ] + settings.stored.sorted { $0.key < $1.key }.map { "\($0.key) = \($0.value)" } + ["", "Log"]
            + Self.recentLog()
        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        } catch {
            Logger(subsystem: "app.komodo.Komodo", category: "settings").error("Diagnostics: \(error)")
            toasts.show(Toast(kind: .error, message: "Couldn't save diagnostics", detail: url.lastPathComponent))
        }
    }

    /// Komodo's own entries since launch. Reading the log can fail, and the file still has everything else.
    private static func recentLog() -> [String] {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            return try store.getEntries(matching: NSPredicate(format: "subsystem == %@", "app.komodo.Komodo"))
                .compactMap { $0 as? OSLogEntryLog }
                .suffix(500)
                .map { "\($0.date.ISO8601Format()) [\($0.category)] \($0.composedMessage)" }
        } catch {
            return ["Couldn't read the log: \(error)"]
        }
    }
}
