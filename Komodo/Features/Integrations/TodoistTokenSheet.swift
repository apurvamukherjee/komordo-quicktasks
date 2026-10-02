import KomodoCore
import SwiftUI

/// Connect Todoist (DESIGN_SYSTEM §13.17, the token sheet in DataSheets.dc.html): paste the personal token, Test
/// it, pick the project and the list it syncs with, then Save. Nothing reaches the Keychain until Save.
struct TodoistTokenSheet: View {
    var lists: [TaskList]
    var cancel: () -> Void
    var save: (_ token: String, _ project: Todoist.Project, _ listID: String) throws(KeychainError) -> Void
    /// Previews pass the projects in, as if Test had already passed.
    var testedProjects: [Todoist.Project] = []

    @State private var token = ""
    @State private var testState = SecureKeyField.TestState.idle
    @State private var projects: [Todoist.Project] = []
    @State private var projectID = ""
    @State private var listID = ""

    private var project: Todoist.Project? { projects.first { $0.id == projectID } }

    var body: some View {
        FormSheet(symbol: "checklist", tint: Palette.teal, glyph: Palette.tealText, letter: "T") {
            VStack(alignment: .leading, spacing: 1) {
                Text("Connect Todoist")
                Text("Two-way · one project · polled every 5 min")
                    .font(.system(size: 12))
                    .tracking(0)
                    .foregroundStyle(Palette.textSecondary)
            }
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Paste your API token")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.textBody)
                    Spacer()
                    if let url = Todoist.tokenHelpURL {
                        Link("Where to find it ↗", destination: url)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.tealText)
                    }
                }
                SecureKeyField(
                    placeholder: "API token", secret: $token, testState: testState,
                    validLabel: "Token works · \(projects.count) project\(projects.count == 1 ? "" : "s") found",
                    idleLabel: "Not tested yet", onTest: test)
            }
            if testState == .valid {
                VStack(spacing: Space.s2) {
                    row("Project") {
                        SettingsMenuPicker(
                            title: "Project", selection: $projectID, options: projects.map { ($0.id, $0.name) })
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
        }
    }

    private func row(_ title: String, @ViewBuilder picker: () -> some View) -> some View {
        HStack {
            Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Palette.textPrimary)
            Spacer()
            picker()
        }
    }

    private func test() {
        testState = .testing
        let candidate = token
        Task {
            do throws(TodoistError) {
                let found = try await TodoistSync.projects(token: candidate)
                // Typing during the test makes the answer stale.
                guard token == candidate else { return }
                accept(found)
            } catch {
                guard token == candidate else { return }
                testState = .invalid(error.message)
            }
        }
    }

    /// Inbox is where everything lands, so the first other project is the likelier pick.
    private func accept(_ found: [Todoist.Project]) {
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

#Preview("Todoist token sheet") {
    VStack(spacing: Space.s6) {
        TodoistTokenSheet(lists: BoardSamples.lists, cancel: {}, save: { _, _, _ in })
        TodoistTokenSheet(
            lists: BoardSamples.lists, cancel: {}, save: { _, _, _ in },
            testedProjects: [
                Todoist.Project(id: "1", name: "Inbox"), Todoist.Project(id: "2", name: "Komodo launch"),
                Todoist.Project(id: "3", name: "Home"),
            ])
    }
    .padding(Space.s8)
    .background(Palette.bg)
}
