import AppKit
import KomodoCore
import SwiftUI

/// Integrations (DESIGN_SYSTEM §13.17, Settings.dc.html): a card per integration, and each one's settings once
/// it's connected. Calendars come through macOS Calendar, so one card covers Google, Microsoft and iCloud alike;
/// the task tools share one card and one settings group.
struct SettingsIntegrationsPage: View {
    @Bindable var store: BoardStore

    private var sync: CalendarSync? { store.calendarSync }
    private var isImporting: Bool { store.settings.importsCalendars && sync?.access == .granted }
    private var connected: [Provider] { Provider.allCases.filter { store.settings[$0].isConnected } }

    @State private var connecting: Provider?

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
                ForEach(Provider.allCases) { provider in
                    ProviderCard(store: store, provider: provider) { connecting = provider }
                }
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
            ForEach(connected) { provider in
                ProviderSettingsGroup(store: store, provider: provider)
            }
        }
        .animation(Motion.base, value: isImporting)
        .animation(Motion.base, value: connected)
        .task {
            #if DEBUG
                // `-openTodoistSheet YES` (or `tested`, and so on per provider) shows the token sheet for captures
                // without the pointer.
                connecting = Provider.allCases.first {
                    UserDefaults.standard.string(forKey: "open\($0.name)Sheet") != nil
                }
            #endif
        }
        .sheet(item: $connecting) { provider in
            ProviderTokenSheet(
                provider: provider, lists: store.lists, cancel: { connecting = nil },
                test: { token throws(ProviderError) in
                    guard let sync = store.providerSyncs[provider] else { throw .unreadable }
                    return try await sync.sources(token: token)
                }
            ) { token, source, listID throws(KeychainError) in
                try store.providerSyncs[provider]?.connect(token: token, source: source, listID: listID)
                connecting = nil
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
