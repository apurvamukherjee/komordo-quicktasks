import AppKit
import KomodoCore
import OSLog
import UniformTypeIdentifiers

extension BoardStore {
    /// About's and Help's Save Diagnostics…: version, macOS, counts and settings in a text file to attach to a bug
    /// report; no tasks or notes leave the Mac.
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
            ] + settings.stored.sorted { $0.key < $1.key }.map { "\($0.key) = \($0.value)" }
        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        } catch {
            Logger(subsystem: "app.komodo.Komodo", category: "settings").error("Diagnostics: \(error)")
            toasts.show(Toast(kind: .error, message: "Couldn't save diagnostics", detail: url.lastPathComponent))
        }
    }
}
