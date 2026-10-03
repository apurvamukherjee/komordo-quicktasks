import KomodoCore
import SwiftUI

/// Connect a task tool (DESIGN_SYSTEM §13.17, the token sheet in DataSheets.dc.html, drawn there for Todoist):
/// paste the personal token, Test it, pick what it syncs and the list it syncs with, then Save. Nothing reaches
/// the Keychain until Save.
struct ProviderTokenSheet: View {
    var provider: Provider
    var lists: [TaskList]
    var cancel: () -> Void
    var test: (_ token: String) async throws(ProviderError) -> [ProviderSource] = { _ throws(ProviderError) in [] }
    var save: (_ token: String, _ project: ProviderSource, _ listID: String) throws(KeychainError) -> Void
    /// Previews pass the projects in, as if Test had already passed.
    var testedProjects: [ProviderSource] = []

    @State private var token = ""
    @State private var testState = SecureKeyField.TestState.idle
    @State private var projects: [ProviderSource] = []
    @State private var projectID = ""
    @State private var listID = ""

    private var project: ProviderSource? { projects.first { $0.id == projectID } }

    /// "Token works · 3 projects found".
    private var validLabel: String {
        let noun = provider.sourceNoun.lowercased()
        let plural = noun == "list" || noun == "team" || noun == "project" ? noun + "s" : "databases"
        return "Token works · \(projects.count) \(projects.count == 1 ? noun : plural) found"
    }

    var body: some View {
        FormSheet(symbol: "checklist", tint: Palette.teal, glyph: Palette.tealText, letter: provider.letter) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Connect \(provider.name)")
                Text(provider.sheetSubtitle)
                    .font(.system(size: 12))
                    .tracking(0)
                    .foregroundStyle(Palette.textSecondary)
            }
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Paste your \(provider.tokenName)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.textBody)
                    Spacer()
                    if let url = provider.tokenHelpURL {
                        Link("Where to find it ↗", destination: url)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.tealText)
                    }
                }
                SecureKeyField(
                    placeholder: provider.tokenName.prefix(1).uppercased() + provider.tokenName.dropFirst(),
                    secret: $token, testState: testState, validLabel: validLabel,
                    idleLabel: "Not tested yet", onTest: runTest)
                if let note = provider.tokenNote {
                    Text(note).font(.system(size: 12)).foregroundStyle(Palette.textSecondary)
                }
            }
            if testState == .valid {
                VStack(spacing: Space.s2) {
                    row(provider.sourceNoun) {
                        SettingsMenuPicker(
                            title: provider.sourceNoun, selection: $projectID,
                            options: projects.map { ($0.id, $0.name) })
                    }
                    row("Sync with list") {
                        SettingsMenuPicker(
                            title: "Sync with list", selection: $listID, options: lists.map { ($0.id, $0.name) })
                    }
                }
            }
            Label("Stored in the macOS Keychain. Never exported.", systemImage: "checkmark.shield")
                .font(.system(size: 12))
                .foregroundStyle(Palette.textBody)
                .labelStyle(KeychainNoteStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .spotlight(Palette.green, radius: 12, lifts: false) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Palette.green.opacity(0.06))
                        .strokeBorder(Palette.green.opacity(0.16), lineWidth: 1)
                }
        } actions: {
            Button("Cancel", action: cancel)
                .buttonStyle(.komodo(.secondary))
                .keyboardShortcut(.cancelAction)
            Button("Save", action: connect)
                .buttonStyle(.komodo(.primary))
                .keyboardShortcut(.defaultAction)
                .disabled(testState != .valid || project == nil || listID.isEmpty)
        }
        .animation(Motion.base, value: testState)
        .onAppear {
            listID = lists.first?.id ?? ""
            if !testedProjects.isEmpty { accept(testedProjects) }
            #if DEBUG
                if UserDefaults.standard.string(forKey: "open\(provider.name)Sheet") == "tested" {
                    token = "0123456789abcdef0123456789abcdef0123c91e"
                    runTest()
                }
            #endif
        }
    }

    private func row(_ title: String, @ViewBuilder picker: () -> some View) -> some View {
        HStack {
            Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Palette.textPrimary)
            Spacer()
            picker()
        }
    }

    private func runTest() {
        testState = .testing
        let candidate = token
        Task {
            do throws(ProviderError) {
                let found = try await test(candidate)
                // Typing during the test makes the answer stale.
                guard token == candidate else { return }
                accept(found)
            } catch {
                guard token == candidate else { return }
                testState = .invalid(error.message(for: .todoist))
            }
        }
    }

    /// Inbox is where everything lands, so the first other project is the likelier pick.
    private func accept(_ found: [ProviderSource]) {
        projects = found
        projectID = (found.first { $0.name != "Inbox" } ?? found.first)?.id ?? ""
        testState = .valid
    }

    private func connect() {
        guard let project else { return }
        do {
            try save(token, project, listID)
        } catch {
            testState = .invalid("The token works, but the Keychain wouldn't save it.")
        }
    }
}

private struct KeychainNoteStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Space.s2) {
            configuration.icon.font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.greenText)
            configuration.title
        }
    }
}

#Preview("Token sheets") {
    HStack(alignment: .top, spacing: Space.s6) {
        ProviderTokenSheet(provider: .todoist, lists: BoardSamples.lists, cancel: {}, save: { _, _, _ in })
        ProviderTokenSheet(
            provider: .clickup, lists: BoardSamples.lists, cancel: {}, save: { _, _, _ in },
            testedProjects: [
                ProviderSource(id: "1", name: "Marketing › Content"),
                ProviderSource(id: "2", name: "Product › Komodo launch"),
                ProviderSource(id: "3", name: "Personal › Errands"),
            ])
        ProviderTokenSheet(provider: .notion, lists: BoardSamples.lists, cancel: {}, save: { _, _, _ in })
    }
    .padding(Space.s8)
    .background(Palette.bg)
}
