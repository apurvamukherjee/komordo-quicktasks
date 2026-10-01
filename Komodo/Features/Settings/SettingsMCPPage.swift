import KomodoCore
import SwiftUI

/// Local MCP server (DESIGN_SYSTEM §13.24, Settings.dc.html): the switch, the setup snippet for each AI app, and
/// the tools they get. Setup and tools dim while the switch is off.
struct SettingsMCPPage: View {
    @Bindable var store: BoardStore

    @State private var client = Client.desktop

    enum Client: String, CaseIterable, Identifiable {
        case desktop
        case code
        case raycast

        var id: Self { self }

        var title: String {
            switch self {
            case .desktop: "Claude Desktop"
            case .code: "Claude Code"
            case .raycast: "Raycast"
            }
        }

        var hint: String {
            switch self {
            case .desktop: "Add to claude_desktop_config.json, then restart Claude Desktop."
            case .code: "Add to .mcp.json in your project."
            case .raycast: "In Raycast, run Install Server and paste this."
            }
        }

        /// The canvas's snippet, pointing at this copy of Komodo's helper.
        func config(helper: String) -> String {
            let server =
                self == .code
                ? """
                      "type": "stdio",
                      "command": "\(helper)"
                """
                : """
                      "command": "\(helper)",
                      "args": []
                """
            return """
                {
                  "mcpServers": {
                    "komodo": {
                \(server)
                    }
                  }
                }
                """
        }
    }

    /// The canvas's tooltips for each tool (Settings.dc.html).
    private static let tools: [(name: String, tip: String)] = [
        ("list_lists", "Lists with IDs"),
        ("list_tasks", "Filter by list, column, date, and status"),
        ("create_task", "Title, list, column, EST, notes, subtasks, schedule"),
        ("update_task", "Any field, including moving between columns or lists"),
        ("complete_task", "Mark done"),
        ("complete_subtask", "Mark done"),
        ("log_time", "Add a manual session"),
        ("start_focus", "Make a task live in Komodo"),
    ]

    /// Where this copy of Komodo keeps the helper, so the snippet works from Applications or a build folder.
    private var helperPath: String {
        Bundle.main.bundleURL.appending(path: "Contents/Helpers/komodo-mcp").path(percentEncoded: false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup(title: "SERVER") {
                SettingsRow(
                    "Let AI apps on this Mac use Komodo",
                    detail: "Works while Komodo is running. No login, and nothing goes through a Komodo server.",
                    isOn: $store.settings.allowsMCP)
            }
            Group {
                SettingsGroup(title: "SETUP") {
                    VStack(alignment: .leading, spacing: Space.s3) {
                        HStack(spacing: Space.s3) {
                            Picker("AI app", selection: $client) {
                                ForEach(Client.allCases) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .fixedSize()
                            Text(client.hint)
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.textSecondary)
                                .lineLimit(1)
                        }
                        CodeBlock(code: client.config(helper: helperPath))
                        Label("The MCP app asks you before each tool call.", systemImage: "checkmark.shield")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textSecondary)
                            .labelStyle(ShieldLabelStyle())
                    }
                    .padding(.horizontal, Space.s4)
                    .padding(.top, 14)
                    .padding(.bottom, Space.s4)
                }
                SettingsGroup(title: "TOOLS") {
                    FlowLayout(spacing: Space.s2) {
                        ForEach(Self.tools, id: \.name) { tool in
                            HStack(spacing: 6) {
                                Circle().fill(Palette.cyan).frame(width: 5, height: 5)
                                Text(tool.name).font(.system(size: 11.5, design: .monospaced))
                            }
                            .foregroundStyle(Palette.textBody)
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(Color.white.opacity(0.05), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
                            .help(tool.tip)
                        }
                    }
                    .padding(.horizontal, Space.s4)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .opacity(store.settings.allowsMCP ? 1 : 0.4)
            .disabled(!store.settings.allowsMCP)
        }
        .animation(Motion.base, value: store.settings.allowsMCP)
    }
}

private struct ShieldLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Space.s2) {
            configuration.icon.font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.green)
            configuration.title
        }
    }
}

#Preview("Local MCP server") {
    SettingsMCPPage(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
        .environment(\.settingsTint, SettingsSection.mcp.spotlight)
        .padding(28)
        .frame(width: 864, height: 720, alignment: .top)
        .background(Palette.bg)
}
