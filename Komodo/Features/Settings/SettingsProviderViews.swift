import KomodoCore
import SwiftUI

/// A task tool's card on Integrations (DESIGN_SYSTEM §13.17, as built for Todoist): Connect, or once connected
/// "● Active" with what it syncs and when it last did, and "Needs attention" with the reason after a failure.
struct ProviderCard: View {
    @Bindable var store: BoardStore
    var provider: Provider
    var connect: () -> Void

    private var connection: ProviderConnection { store.settings[provider] }
    private var sync: ProviderSync? { store.providerSyncs[provider] }

    var body: some View {
        let problem = connection.isConnected ? connection.problem : nil
        IntegrationCard(
            name: provider.name,
            detail: problem.map { Text(provider.cardDetail + " ") + Text($0).foregroundColor(Palette.dangerText) }
                ?? Text(provider.cardDetail),
            status: problem != nil ? .attention : connection.isConnected ? .active("Active") : .none,
            tint: Palette.textSecondary
        ) {
            Text(provider.letter)
        } footer: {
            if connection.isConnected {
                Text(syncLine)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textBody)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Sync now") { Task { await sync?.sync() } }
                    .buttonStyle(.komodo(.secondary, size: .small, isBusy: sync?.isSyncing == true))
            } else {
                Spacer()
                Button("Connect", action: connect)
                    .buttonStyle(.komodo(.secondary, size: .small))
                    .disabled(sync == nil)
            }
        }
    }

    /// "Komodo launch · Synced 9:41 AM".
    private var syncLine: String {
        guard let last = connection.lastSync else { return connection.sourceName }
        return connection.sourceName + " · Synced " + last.formatted(.dateTime.hour().minute())
    }
}

/// A connected task tool's settings (FEATURES §5 "Common settings"): what it syncs with, the date and status
/// mappings where the provider has them, Auto sync, Sync deletes for two-way providers, Only my items, and
/// Disconnect.
struct ProviderSettingsGroup: View {
    @Bindable var store: BoardStore
    var provider: Provider

    private var connection: ProviderConnection { store.settings[provider] }
    private var sync: ProviderSync? { store.providerSyncs[provider] }
    private var name: String { provider.name }

    var body: some View {
        SettingsGroup(title: name.uppercased()) {
            SettingsRow(
                provider.sourceNoun,
                detail: "To sync another \(provider.sourceNoun.lowercased()), disconnect and connect again."
            ) {
                Text(connection.sourceName)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
            }
            SettingsRow("Sync with list", detail: "Its \(provider.itemNoun) join this list, placed by their date.") {
                SettingsMenuPicker(
                    title: "Sync with list",
                    selection: binding(\.listID, default: store.lists.first?.id ?? ""),
                    options: store.lists.map { ($0.id, $0.name) })
            }
            if provider.hasDateMapping {
                SettingsRow("Schedule by", detail: "Which \(name) date puts a task on the Board.") {
                    SettingsMenuPicker(
                        title: "Schedule by",
                        selection: Binding(
                            get: { connection.dateMapping }, set: { sync?.setDateMapping($0) }),
                        options: [(DateMapping.start, "Start date"), (.due, "Due date")])
                }
            }
            if provider.hasStatusMapping, !connection.statuses.isEmpty {
                SettingsRow(
                    "Status mapping",
                    detail: "Where an undated \(provider.itemNoun.dropLast()) goes in each \(name) status. "
                        + "A dated one goes by its date."
                ) {
                    EmptyView()
                }
                ForEach(connection.statuses, id: \.name) { status in
                    SettingsRow(status.name, isIndented: true) {
                        SettingsMenuPicker(
                            title: status.name, selection: target(for: status),
                            options: StatusTarget.allCases.map { ($0, Self.title(for: $0)) })
                    }
                }
            }
            SettingsRow(
                "Auto sync", detail: "Check \(name) for changes every 5 minutes.",
                isOn: Binding(get: { connection.autoSync }, set: { store.settings[provider].autoSync = $0 }))
            if provider.isTwoWay {
                SettingsRow(
                    "Sync deletes",
                    detail: "Deleting a task here deletes it in \(name) too. Deleting in \(name) only unlinks it here.",
                    isOn: Binding(
                        get: { connection.syncsDeletes }, set: { store.settings[provider].syncsDeletes = $0 }))
            }
            SettingsRow(
                "Only my items", detail: "Skip \(provider.itemNoun) assigned to someone else.",
                isOn: Binding(
                    get: { connection.onlyMine },
                    set: {
                        store.settings[provider].onlyMine = $0
                        Task { await sync?.sync() }
                    }))
            SettingsRow("Stop syncing", detail: "Tasks already imported stay on the Board.") {
                Button("Disconnect") { sync?.disconnect() }
                    .buttonStyle(.komodo(.ghost, size: .small))
            }
        }
    }

    static func title(for target: StatusTarget) -> String {
        switch target {
        case .byDate: "By date"
        case .backlog: BoardStore.title(for: .backlog)
        case .week: BoardStore.title(for: .week)
        case .today: BoardStore.title(for: .today)
        case .done: "Done"
        }
    }

    private func binding(_ key: WritableKeyPath<ProviderConnection, String?>, default value: String) -> Binding<String>
    {
        Binding(get: { connection[keyPath: key] ?? value }, set: { store.settings[provider][keyPath: key] = $0 })
    }

    /// A new choice takes effect on the next pull, which reads every open item again.
    private func target(for status: ProviderStatus) -> Binding<StatusTarget> {
        Binding(
            get: { connection.target(for: status) },
            set: {
                store.settings[provider].statusTargets[status.name] = $0
                Task { await sync?.sync() }
            })
    }
}

#Preview("Provider settings") {
    let store = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)
    store.settings[.clickup].sourceID = "901"
    store.settings[.clickup].sourceName = "Product › Komodo launch"
    store.settings[.clickup].dateMapping = .start
    store.settings[.clickup].statuses = [
        ProviderStatus(name: "to do", kind: .todo), ProviderStatus(name: "in progress", kind: .active),
        ProviderStatus(name: "complete", kind: .done),
    ]
    return VStack(spacing: Space.s4) {
        HStack(spacing: 12) {
            ProviderCard(store: store, provider: .clickup, connect: {})
            ProviderCard(store: store, provider: .linear, connect: {})
        }
        ProviderSettingsGroup(store: store, provider: .clickup)
    }
    .environment(\.settingsTint, SettingsSection.integrations.spotlight)
    .padding(28)
    .frame(width: 864)
    .background(Palette.bg)
}
