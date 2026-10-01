import SwiftUI

/// The Settings window's pages, in sidebar order (Settings.dc.html). Pages whose milestone hasn't landed show
/// dimmed.
enum SettingsSection: String, CaseIterable, Identifiable, Sendable {
    case general
    case focus
    case alerts
    case celebration
    case shortcuts
    case gmail
    case integrations
    case data
    case ai
    case mcp
    case about

    var id: Self { self }

    /// Sidebar groups, split by hairlines.
    static let groups: [[SettingsSection]] = [
        [.general, .focus, .alerts, .celebration, .shortcuts],
        [.gmail, .integrations, .data, .ai, .mcp],
        [.about],
    ]

    var title: String {
        switch self {
        case .general: "General"
        case .focus: "Focus"
        case .alerts: "Alerts & sounds"
        case .celebration: "Celebration"
        case .shortcuts: "Shortcuts"
        case .gmail: "Gmail → Calendar"
        case .integrations: "Integrations"
        case .data: "Data & backup"
        case .ai: "AI"
        case .mcp: "Local MCP server"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .focus: "bolt"
        case .alerts: "speaker.wave.2"
        case .celebration: "party.popper"
        case .shortcuts: "keyboard"
        case .gmail: "calendar.badge.plus"
        case .integrations: "puzzlepiece.extension"
        case .data: "archivebox"
        case .ai: "sparkles"
        case .mcp: "apple.terminal"
        case .about: "checkmark"
        }
    }

    /// The icon square's color.
    var tint: Color {
        switch self {
        case .general: Palette.textSecondary
        case .focus, .about: Palette.lime
        case .alerts: Palette.pink
        case .celebration: Palette.amber
        case .shortcuts: Palette.textTertiary
        case .gmail: Palette.blue
        case .integrations: Palette.teal
        case .data: Palette.green
        case .ai: Palette.violet
        case .mcp: Palette.cyan
        }
    }

    /// The page's spotlight; the grey pages light up teal.
    var spotlight: Color {
        switch self {
        case .general, .shortcuts: SpotlightTint.info
        default: tint
        }
    }

    /// Why a page isn't there yet, or nil when it is.
    var comingIn: String? {
        switch self {
        case .gmail: "Gmail → Calendar arrives in the next milestone"
        case .ai: "Arrives in Phase 1"
        default: nil
        }
    }

    /// Words the sidebar search matches besides the title: each page's row titles.
    var keywords: [String] {
        switch self {
        case .general:
            ["login", "dock", "menu bar", "week starts", "presets", "estimate", "hide"]
        case .focus:
            ["panel", "screen", "side", "full-screen", "pomodoro", "sprint", "break", "scrolling", "links"]
        case .alerts: ["timed", "sound", "pulse", "reminder", "volume"]
        case .celebration: ["success", "gif", "confetti"]
        case .shortcuts: ["keyboard", "global", "hotkey"]
        case .gmail: ["calendar", "email"]
        case .integrations: ["calendar", "google", "outlook", "icloud", "notion", "todoist", "linear"]
        case .data: ["backup", "export", "restore", "delete"]
        case .ai: ["claude", "api key", "apple intelligence"]
        case .mcp: ["claude", "raycast"]
        case .about: ["version", "updates", "diagnostics"]
        }
    }

    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return ([title] + keywords).contains { $0.localizedCaseInsensitiveContains(query) }
    }
}
