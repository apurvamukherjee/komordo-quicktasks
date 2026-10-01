import KomodoCore
import OSLog
import SwiftUI

/// AI (DESIGN_SYSTEM §13.23, Settings.dc.html): Apple Intelligence's status, and Claude with the user's own key,
/// the model and what Claude is used for. The key is saved to the Keychain once Test accepts it.
struct SettingsAIPage: View {
    @Bindable var store: BoardStore

    @State private var key = ""
    @State private var testState = SecureKeyField.TestState.idle
    private let status = AppleIntelligence.status

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup(title: "APPLE INTELLIGENCE") {
                SettingsRow("Apple Intelligence", detail: "The on-device model. Email never leaves this Mac.") {
                    HStack(spacing: 7) {
                        Circle().fill(statusColor).frame(width: 7, height: 7)
                        Text(statusText)
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(status == .available ? Palette.greenText : Palette.textSecondary)
                }
            }
            .environment(\.settingsTint, Palette.green)
            SettingsGroup(title: "CLAUDE") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("API key").font(.system(size: 13.5, weight: .semibold)).foregroundStyle(
                                Palette.textBody)
                            Text("Your own Anthropic key.").font(.system(size: 12)).foregroundStyle(Palette.textMuted)
                        }
                        Spacer()
                        if store.settings.hasClaudeKey {
                            Button("Remove") { removeKey() }.buttonStyle(.komodo(.ghost, size: .small))
                        }
                    }
                    SecureKeyField(placeholder: "sk-ant-…", secret: $key, testState: testState) { test() }
                }
                .padding(.horizontal, Space.s4)
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
                SettingsRow("Model") {
                    SettingsMenuPicker(
                        title: "Model", selection: $store.settings.claudeModel,
                        options: AppSettings.claudeModels.map { ($0, $0) })
                }
                SettingsRow("Use Claude for") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Gmail → Calendar", isOn: .constant(false))
                            .help("Arrives with Gmail → Calendar")
                        HStack(spacing: 6) {
                            Toggle("Komodo Assistant", isOn: .constant(false))
                            Chip("P2", tint: .outline, size: .compact)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .font(.system(size: 13))
                    .disabled(true)
                    .frame(minWidth: 250, alignment: .leading)
                }
                Label(
                    "Billed to your Anthropic account. The key is stored in the macOS Keychain.",
                    systemImage: "lock.shield"
                )
                .font(.system(size: 12))
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Space.s4)
                .padding(.vertical, 14)
            }
        }
        .onAppear(perform: loadKey)
        .onChange(of: key) { testState = .idle }
    }

    private var statusText: String {
        switch status {
        case .available: "Available: used by On this Mac mode"
        case .turnedOff: "Turned off in System Settings"
        case .unsupportedMac: "Not available on this Mac"
        case .needsNewerMacOS: "Needs macOS 26 or later"
        }
    }

    private var statusColor: Color { status == .available ? Palette.green : Palette.textMuted }

    // MARK: Key

    /// Only a saved key is read, so opening the page never asks the Keychain for nothing.
    private func loadKey() {
        guard store.settings.hasClaudeKey else { return }
        do {
            key = try KeychainSecret.claudeKey.read() ?? ""
        } catch {
            Logger(subsystem: "app.komodo.Komodo", category: "ai").error("Couldn't read the Claude key: \(error)")
        }
    }

    private func test() {
        testState = .testing
        let candidate = key
        let model = store.settings.claudeModel
        Task {
            let result = await ClaudeKeyCheck.run(candidate, model: model)
            // Typing during the test makes the answer stale.
            guard key == candidate else { return }
            testState = result
            guard result == .valid else { return }
            do {
                try KeychainSecret.claudeKey.save(candidate.trimmingCharacters(in: .whitespacesAndNewlines))
                store.settings.hasClaudeKey = true
            } catch {
                testState = .invalid("The key works, but the Keychain wouldn't save it.")
            }
        }
    }

    private func removeKey() {
        do {
            try KeychainSecret.claudeKey.remove()
        } catch {
            Logger(subsystem: "app.komodo.Komodo", category: "ai").error("Couldn't remove the Claude key: \(error)")
            return
        }
        store.settings.hasClaudeKey = false
        key = ""
    }
}

#Preview("AI") {
    SettingsAIPage(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
        .environment(\.settingsTint, SettingsSection.ai.spotlight)
        .padding(28)
        .frame(width: 864, height: 720, alignment: .top)
        .background(Palette.bg)
}
