import KomodoCore
import OSLog
import ServiceManagement
import SwiftUI

/// General (Settings.png): the app's place on the Mac, then how the Board reads.
struct SettingsGeneralPage: View {
    @Bindable var store: BoardStore

    /// The system is the source of truth for the login item, so it's read back rather than stored.
    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup(title: "APP") {
                SettingsRow(
                    "Open Komodo at login", detail: "Keeps Gmail → Calendar and reminders running.",
                    isOn: Binding(get: { opensAtLogin }, set: setOpensAtLogin))
                SettingsRow(
                    "Show Komodo in the Dock", detail: "Turn off to keep Komodo in the menu bar only.",
                    isOn: $store.settings.showsInDock)
                SettingsRow(
                    "Show timer in the menu bar", detail: "The live task's time sits next to the Komodo mark.",
                    isOn: $store.settings.showsMenuBarTimer)
            }
            SettingsGroup(title: "BOARD") {
                SettingsRow("Week starts on", detail: "Sets the This week column and the week strip.") {
                    SettingsMenuPicker(
                        title: "Week starts on", selection: $store.settings.weekStart,
                        options: WeekStart.allCases.map { ($0, $0.title) })
                }
                SettingsRow("Quick task presets", detail: "One-click estimates under every add field.") {
                    PresetEditor(presets: $store.settings.quickPresets)
                }
                SettingsRow(
                    "Hide EST and time taken on cards", detail: "A calmer board. Timers keep counting.",
                    isOn: $store.settings.hidesCardTimes)
            }
        }
    }

    private func setOpensAtLogin(_ isOn: Bool) {
        do {
            if isOn {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger(subsystem: "app.komodo.Komodo", category: "settings").error("Login item: \(error)")
            store.toasts.show(
                Toast(
                    kind: .error, message: "Couldn't change Open at login",
                    detail: "Check Login Items in System Settings."))
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }
}

/// `.st-preset`: each estimate as a chip with ✕, and + offering a few more, up to five.
private struct PresetEditor: View {
    @Binding var presets: [TimeInterval]

    private static let candidates: [TimeInterval] = [5, 10, 20, 45, 90, 120].map { $0 * 60 }

    var body: some View {
        HStack(spacing: Space.s2) {
            ForEach(presets, id: \.self) { seconds in
                chip(seconds)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            Menu {
                ForEach(Self.candidates.filter { !presets.contains($0) }, id: \.self) { seconds in
                    Button(DurationFormat.compact(seconds)) { presets = (presets + [seconds]).sorted() }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(
                        Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08)))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .disabled(presets.count >= AppSettings.presetLimit)
            .help("Add a preset")
            .accessibilityLabel("Add a preset")
        }
        .animation(Motion.spring, value: presets)
    }

    private func chip(_ seconds: TimeInterval) -> some View {
        let label = DurationFormat.compact(seconds)
        let shape = RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
        return HStack(spacing: Space.s1) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.textBody)
            Button("Remove \(label) preset", systemImage: "xmark") { presets.removeAll { $0 == seconds } }
                .labelStyle(.iconOnly)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Palette.textMuted)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .frame(height: 26)
        .background(Color.white.opacity(0.06), in: shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.08)))
    }
}

#Preview("General") {
    SettingsGeneralPage(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
        .padding(28)
        .frame(width: 864)
        .background(Palette.bg)
}
