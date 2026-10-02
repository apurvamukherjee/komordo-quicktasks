import AppKit
import KomodoCore
import SwiftUI

/// Integrations (DESIGN_SYSTEM §13.17, Settings.dc.html): a card per integration, calendar import's and Todoist's
/// settings once they're connected, and the providers still to come. Calendars come through macOS Calendar, so
/// one card covers Google, Microsoft and iCloud alike.
struct SettingsIntegrationsPage: View {
    @Bindable var store: BoardStore

    private static let comingSoon: [(letter: String, name: String, detail: String)] = [
        ("N", "Notion", "Sync a database."),
        ("L", "Linear", "Import a team's issues."),
        ("C", "ClickUp", "Sync spaces, folders, and lists."),
        ("A", "Asana", "Sync projects."),
    ]

    private var sync: CalendarSync? { store.calendarSync }
    private var isImporting: Bool { store.settings.importsCalendars && sync?.access == .granted }
    private var todoist: TodoistSync? { store.todoistSync }
    private var isTodoistConnected: Bool { store.settings.todoistProjectID != nil }

    @State private var isConnectingTodoist = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(
                "Everything runs on this Mac. Tokens are stored in the macOS Keychain.", systemImage: "checkmark.shield"
            )
            .font(.system(size: 13))
            .foregroundStyle(Palette.textBody)
            .labelStyle(GreenIconLabelStyle())
            .padding(.horizontal, Space.s1)
            .padding(.bottom, 14)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                calendarCard
                todoistCard
                mcpCard
                IntegrationCard(
                    name: "Gmail → Calendar",
                    detail: Text("Meetings and deadlines from email, added to Komodo's own calendars."),
                    status: .comingSoon, tint: Palette.textTertiary
                ) {
                    Text("G")
                } footer: {
                    EmptyView()
                }
            }
            if isImporting { calendarSettings }
            if isTodoistConnected { todoistSettings }
            Text("COMING SOON")
                .font(Typography.label)
                .tracking(Typography.Tracking.label)
                .foregroundStyle(Palette.textMuted)
                .padding(.horizontal, Space.s1)
                .padding(.top, 18)
                .padding(.bottom, Space.s2)
            HStack(alignment: .top, spacing: 10) {
                ForEach(Self.comingSoon, id: \.name) { provider in
                    VStack(alignment: .leading, spacing: Space.s2) {
                        HStack {
                            Text(provider.letter)
                                .font(.system(size: 14, weight: .heavy))
                                .frame(width: 30, height: 30)
                                .background(Palette.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Spacer()
                            Chip("Coming soon", size: .compact)
                        }
                        Text(provider.name).font(.system(size: 13, weight: .semibold))
                        Text(provider.detail).font(.system(size: 11.5)).foregroundStyle(Palette.textSecondary)
                    }
                    .foregroundStyle(Palette.textPrimary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .spotlight(Palette.textSecondary, radius: Radius.tile) { TileSurface() }
                    .opacity(0.6)
                }
            }
        }
        .animation(Motion.base, value: isImporting)
        .animation(Motion.base, value: isTodoistConnected)
        .task {
            #if DEBUG
                // `-openTodoistSheet YES` (or `tested`) shows the token sheet for captures without the pointer.
                isConnectingTodoist = UserDefaults.standard.string(forKey: "openTodoistSheet") != nil
            #endif
        }
        .sheet(isPresented: $isConnectingTodoist) {
            TodoistTokenSheet(lists: store.lists, cancel: { isConnectingTodoist = false }) {
                token, project, listID throws(KeychainError) in
                try todoist?.connect(token: token, project: project, listID: listID)
                isConnectingTodoist = false
            }
        }
    }

    // MARK: Cards

    @ViewBuilder private var calendarCard: some View {
        let access = sync?.access ?? .notDetermined
        IntegrationCard(
            name: "Calendar import",
            detail: access == .denied
                ? Text("Show calendar events as tasks. ")
                    + Text("Calendar access is off. Allow Komodo in System Settings.").foregroundColor(
                        Palette.dangerText)
                : Text("Show events from the calendars on this Mac as tasks: iCloud, Google, Outlook and more."),
            status: access == .denied ? .attention : isImporting ? .active("Active") : .none, tint: Palette.blue
        ) {
            Image(systemName: "calendar").font(.system(size: 14, weight: .semibold))
        } footer: {
            if access == .denied {
                Spacer()
                Button("Open System Settings") { openPrivacySettings() }
                    .buttonStyle(.komodo(.dangerOutline, size: .small))
            } else if isImporting {
                Text(syncLine)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textBody)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Sync now") { sync?.sync() }
                    .buttonStyle(.komodo(.secondary, size: .small, isBusy: sync?.isSyncing == true))
            } else {
                Spacer()
                Button("Connect") { Task { await sync?.connect() } }
                    .buttonStyle(.komodo(.secondary, size: .small))
                    .disabled(sync == nil)
            }
        }
    }

    @ViewBuilder private var todoistCard: some View {
        let problem = isTodoistConnected ? store.settings.todoistProblem : nil
        IntegrationCard(
            name: "Todoist",
            detail: problem.map {
                Text("Sync one project with a list. ") + Text($0).foregroundColor(Palette.dangerText)
            }
                ?? Text("Sync one project with a list, both ways."),
            status: problem != nil ? .attention : isTodoistConnected ? .active("Active") : .none,
            tint: Palette.textSecondary
        ) {
            Text("T")
        } footer: {
            if isTodoistConnected {
                Text(todoistSyncLine)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textBody)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Sync now") { Task { await todoist?.sync() } }
                    .buttonStyle(.komodo(.secondary, size: .small, isBusy: todoist?.isSyncing == true))
            } else {
                Spacer()
                Button("Connect") { isConnectingTodoist = true }
                    .buttonStyle(.komodo(.secondary, size: .small))
                    .disabled(todoist == nil)
            }
        }
    }

    /// "Komodo launch · Synced 9:41 AM".
    private var todoistSyncLine: String {
        let project = store.settings.todoistProjectName
        guard let last = store.settings.lastTodoistSync else { return project }
        return project + " · Synced " + last.formatted(.dateTime.hour().minute())
    }

    private var mcpCard: some View {
        IntegrationCard(
            name: "Local MCP server",
            detail: Text("Let Claude Desktop, Claude Code, and Raycast use Komodo on this Mac."),
            status: store.settings.allowsMCP ? .active("On") : .off, tint: Palette.cyan
        ) {
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.cyan)
        } footer: {
            Spacer()
            Button("Set up") { store.settingsSection = .mcp }
                .buttonStyle(.komodo(.secondary, size: .small))
        }
    }

    /// "2 calendars · Synced 9:41 AM".
    private var syncLine: String {
        let count = store.settings.calendarIDs.count
        let calendars = "\(count) calendar\(count == 1 ? "" : "s")"
        guard let last = store.settings.lastCalendarSync else { return calendars }
        return calendars + " · Synced " + last.formatted(.dateTime.hour().minute())
    }

    // MARK: Calendar import

    private var calendarSettings: some View {
        SettingsGroup(title: "CALENDAR IMPORT") {
            ForEach(accounts, id: \.self) { account in
                Text(account)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Space.s4)
                    .padding(.top, 12)
                    .padding(.bottom, 2)
                ForEach(sync?.calendars.filter { $0.account == account } ?? []) { choice in
                    SettingsRow(choice.title, isIndented: true) {
                        Circle().fill(choice.color).frame(width: 8, height: 8)
                        SettingsSwitch(title: choice.title, isOn: isChosen(choice.id))
                    }
                }
            }
            SettingsRow("Add to list", detail: "Imported events join this list, placed by their date.") {
                SettingsMenuPicker(
                    title: "Add to list", selection: listChoice,
                    options: store.lists.map { ($0.id, $0.name) })
            }
            SettingsRow("Range", detail: "How far ahead events are imported.") {
                SettingsMenuPicker(
                    title: "Range", selection: rangeChoice,
                    options: AppSettings.calendarWeekChoices.map { ($0, $0 == 1 ? "Next week" : "Next \($0) weeks") })
            }
            SettingsRow(
                "Only accepted events", detail: "Skip invitations you haven't accepted.",
                isOn: Binding(
                    get: { store.settings.calendarAcceptedOnly },
                    set: {
                        store.settings.calendarAcceptedOnly = $0
                        sync?.sync()
                    }))
            SettingsRow("Stop importing", detail: "Tasks already imported stay on the Board.") {
                Button("Disconnect") { sync?.disconnect() }
                    .buttonStyle(.komodo(.ghost, size: .small))
            }
        }
    }

    // MARK: Todoist

    private var todoistSettings: some View {
        SettingsGroup(title: "TODOIST") {
            SettingsRow("Project", detail: "To sync another project, disconnect and connect again.") {
                Text(store.settings.todoistProjectName)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
            }
            SettingsRow("Sync with list", detail: "Its tasks join this list, placed by their date.") {
                SettingsMenuPicker(
                    title: "Sync with list", selection: todoistListChoice,
                    options: store.lists.map { ($0.id, $0.name) })
            }
            SettingsRow(
                "Auto sync", detail: "Check Todoist for changes every 5 minutes.",
                isOn: Binding(get: { store.settings.todoistAutoSync }, set: { store.settings.todoistAutoSync = $0 }))
            SettingsRow(
                "Sync deletes",
                detail: "Deleting a task here deletes it in Todoist too. Deleting in Todoist only unlinks it here.",
                isOn: Binding(
                    get: { store.settings.todoistSyncsDeletes }, set: { store.settings.todoistSyncsDeletes = $0 }))
            SettingsRow(
                "Only my items", detail: "Skip tasks assigned to someone else.",
                isOn: Binding(
                    get: { store.settings.todoistOnlyMine },
                    set: {
                        store.settings.todoistOnlyMine = $0
                        Task { await todoist?.sync() }
                    }))
            SettingsRow("Stop syncing", detail: "Tasks already imported stay on the Board.") {
                Button("Disconnect") { todoist?.disconnect() }
                    .buttonStyle(.komodo(.ghost, size: .small))
            }
        }
    }

    private var todoistListChoice: Binding<String> {
        Binding(
            get: { store.settings.todoistListID ?? store.lists.first?.id ?? "" },
            set: { store.settings.todoistListID = $0 })
    }

    private var accounts: [String] {
        (sync?.calendars ?? []).reduce(into: [String]()) { if !$0.contains($1.account) { $0.append($1.account) } }
    }

    private func isChosen(_ id: String) -> Binding<Bool> {
        Binding(
            get: { store.settings.calendarIDs.contains(id) },
            set: { isOn in
                store.settings.calendarIDs.removeAll { $0 == id }
                if isOn { store.settings.calendarIDs.append(id) }
                sync?.sync()
            })
    }

    private var listChoice: Binding<String> {
        Binding(
            get: { store.settings.calendarListID ?? store.lists.first?.id ?? "" },
            set: {
                store.settings.calendarListID = $0
                sync?.sync()
            })
    }

    private var rangeChoice: Binding<Int> {
        Binding(
            get: { store.settings.calendarWeeks },
            set: {
                store.settings.calendarWeeks = $0
                sync?.sync()
            })
    }

    private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct GreenIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Space.s2) {
            configuration.icon.font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.green)
            configuration.title
        }
    }
}

#Preview("Integrations") {
    SettingsIntegrationsPage(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
        .environment(\.settingsTint, SettingsSection.integrations.spotlight)
        .padding(28)
        .frame(width: 864, height: 720, alignment: .top)
        .background(Palette.bg)
}
