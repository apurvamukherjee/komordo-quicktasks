import AppKit
import KomodoCore
import SwiftUI

/// Shortcuts (Settings.dc.html): every shortcut in one table. The global ones record new keys; the app's own are
/// the menu shortcuts and stay fixed.
struct SettingsShortcutsPage: View {
    @Bindable var store: BoardStore

    @State private var recording: GlobalShortcut?

    /// The menu shortcuts, in the canvas's order.
    private static let appShortcuts: [(action: String, keys: [String])] = [
        ("New task", ["⌘", "⌥", "T"]),
        ("Start break", ["⌘", "⌥", "B"]),
        ("Pause / resume", ["⌘", "⌥", "P"]),
        ("Skip", ["⌘", "⌥", "S"]),
        ("Done", ["⌘", "⌥", "F"]),
        ("Notes on the live task", ["⌘", "⌥", "N"]),
        ("Search", ["⌘", "F"]),
        ("Settings", ["⌘", ","]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup(title: "KEYBOARD SHORTCUTS") {
                ShortcutColumns(
                    action: header("ACTION"), keys: header("SHORTCUT"), scope: header("SCOPE"),
                    reset: header("RESET")
                )
                .padding(.top, 10)
                .padding(.bottom, Space.s2)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }
                ForEach(GlobalShortcut.allCases, id: \.self) { action in
                    globalRow(action)
                }
                ForEach(Self.appShortcuts, id: \.action) { shortcut in
                    row(shortcut.action, isGlobal: false) {
                        HStack(spacing: Space.s1) { caps(shortcut.keys) }.padding(.horizontal, Space.s2)
                    } reset: {
                        // Holds the column, so the keys line up with the global rows'.
                        Color.clear.frame(height: 1)
                    }
                }
            }
            Label(
                "Global shortcuts work from any app and can be changed here. Click a shortcut, then press the new keys.",
                systemImage: "info.circle"
            )
            .font(.system(size: 12))
            .foregroundStyle(Palette.textMuted)
            .padding(.horizontal, Space.s1)
            .padding(.top, Space.s3)
        }
        .environment(\.settingsTint, Palette.teal)
    }

    private func globalRow(_ action: GlobalShortcut) -> some View {
        let isCustom = store.settings.shortcuts[action] != nil
        return row(action.title, isGlobal: true) {
            VStack(alignment: .leading, spacing: Space.s1) {
                ShortcutRecorder(
                    action: action, combo: store.settings.shortcut(for: action), recording: $recording,
                    isConflicted: store.shortcutConflicts.contains(action)
                ) { combo in
                    store.settings.shortcuts[action] = combo == action.defaultCombo ? nil : combo
                }
                if store.shortcutConflicts.contains(action) {
                    Label("Used by another app", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Palette.dangerText)
                        .padding(.leading, 6)
                }
            }
            .padding(.vertical, 3)
        } reset: {
            Button("Reset \(action.title)", systemImage: "arrow.counterclockwise") {
                store.settings.shortcuts[action] = nil
            }
            .labelStyle(.iconOnly)
            .buttonStyle(IconButtonStyle())
            .disabled(!isCustom)
            .opacity(isCustom ? 1 : 0.35)
            .help("Reset to \(action.defaultCombo.label)")
        }
    }

    private func row<Keys: View, Reset: View>(
        _ action: String, isGlobal: Bool, @ViewBuilder keys: () -> Keys, @ViewBuilder reset: () -> Reset
    ) -> some View {
        ShortcutColumns(
            action: Text(action).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Palette.textBody),
            keys: keys(),
            scope: Chip(isGlobal ? "Global" : "App", tint: isGlobal ? .teal : .neutral, size: .compact),
            reset: reset()
        )
        .padding(.vertical, 6)
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.045)).frame(height: 1) }
    }

    private func header(_ title: String) -> some View {
        Text(title).font(Typography.label).tracking(Typography.Tracking.label).foregroundStyle(Palette.textMuted)
    }
}

/// `.st-tgrid`: the action takes what's left beside 230, 84 and 40 pt columns.
private struct ShortcutColumns<Action: View, Keys: View, Scope: View, Reset: View>: View {
    var action: Action
    var keys: Keys
    var scope: Scope
    var reset: Reset

    var body: some View {
        HStack(spacing: Space.s3) {
            action.frame(maxWidth: .infinity, alignment: .leading)
            keys.frame(width: 230, alignment: .leading)
            scope.frame(width: 84, alignment: .leading)
            reset.frame(width: 40, alignment: .trailing)
        }
        .padding(.horizontal, Space.s4)
    }
}

@MainActor private func caps(_ keys: [String]) -> some View {
    ForEach(Array(keys.enumerated()), id: \.offset) { _, key in KeyCap(key) }
}

/// `.st-rec`: the shortcut's caps in a pill; a click starts recording and the next key with ⌘, ⌥ or ⌃ becomes
/// the shortcut. Esc cancels.
private struct ShortcutRecorder: View {
    var action: GlobalShortcut
    var combo: KeyCombo
    @Binding var recording: GlobalShortcut?
    var isConflicted: Bool
    var onRecord: (KeyCombo) -> Void

    @State private var monitor: Any?
    @State private var isHovered = false

    private var isRecording: Bool { recording == action }

    var body: some View {
        Button {
            recording = isRecording ? nil : action
        } label: {
            HStack(spacing: Space.s1) {
                if isRecording {
                    Circle().fill(Palette.teal).frame(width: 6, height: 6).padding(.horizontal, 2)
                    Text("Recording… press keys")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.tealText)
                        .lineLimit(1)
                } else {
                    caps(combo.caps)
                    Spacer(minLength: Space.s1)
                    Image(systemName: "plus.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textMuted)
                }
            }
            .padding(.leading, Space.s2)
            .padding(.trailing, 10)
            .frame(minWidth: 150, minHeight: 30)
            .background(background, in: Capsule())
            .overlay(Capsule().strokeBorder(border, lineWidth: 1))
            .contentShape(Capsule())
            .fixedSize()
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(Motion.fast, value: isRecording)
        .accessibilityLabel(
            isRecording ? "Recording a shortcut for \(action.title)" : "\(action.title), \(combo.label)"
        )
        .accessibilityHint("Click, then press the new keys")
        .onChange(of: isRecording) { _, isOn in isOn ? startMonitor() : stopMonitor() }
        .onDisappear {
            stopMonitor()
            if isRecording { recording = nil }
        }
    }

    private var background: Color {
        if isRecording { return Palette.teal.opacity(0.08) }
        if isConflicted { return Palette.danger.opacity(0.07) }
        return Color.white.opacity(isHovered ? 0.07 : 0.04)
    }

    private var border: Color {
        if isRecording { return Palette.teal }
        if isConflicted { return Palette.danger.opacity(0.8) }
        return Color.white.opacity(isHovered ? 0.24 : 0.12)
    }

    private func startMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Esc cancels; a plain letter would take over typing in every app, so it's refused with a beep.
            if event.keyCode == 53 {
                recording = nil
                return nil
            }
            guard let combo = KeyCombo(event: event), combo.isUsable else {
                NSSound.beep()
                return nil
            }
            onRecord(combo)
            recording = nil
            return nil
        }
    }

    private func stopMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

extension KeyCombo {
    /// The key as the current layout prints it, so a recorded shortcut reads the way the keyboard does.
    init?(event: NSEvent) {
        guard let key = event.charactersIgnoringModifiers?.uppercased(), !key.isEmpty else { return nil }
        var modifiers: Modifiers = []
        let flags = event.modifierFlags
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.control) { modifiers.insert(.control) }
        self.init(keyCode: UInt32(event.keyCode), modifiers: modifiers, key: key)
    }
}

#Preview("Shortcuts") {
    SettingsShortcutsPage(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
        .padding(28)
        .frame(width: 864)
        .background(Palette.bg)
}
