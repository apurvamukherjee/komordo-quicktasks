import AppKit
import KomodoCore
import SwiftUI

/// Focus (Settings.dc.html): where the Focus Panel docks, with a live preview, then Pomodoros and what happens
/// while a task is live. Pomodoros, both lengths and the side are Quick Settings' own values.
struct SettingsFocusPage: View {
    @Bindable var store: BoardStore

    /// Quick Settings' ranges, so both views step the same way.
    private static let sprintRange = 5...90
    private static let breakRange = 1...30

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                SettingsGroup(title: "FOCUS PANEL") {
                    SettingsRow("Panel screen", detail: "Where the Focus Panel docks.") {
                        SettingsMenuPicker(
                            title: "Panel screen", selection: $store.settings.panelScreen,
                            options: screenOptions)
                    }
                    SettingsRow("Panel side", detail: "The panel hugs this edge of the screen.") {
                        Picker("Panel side", selection: $store.panelSide) {
                            Text("Left").tag(BoardStore.PanelSide.left)
                            Text("Right").tag(BoardStore.PanelSide.right)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                    SettingsRow(
                        "Float above full-screen apps", detail: "Keeps the panel and floating timer in view.",
                        isOn: $store.settings.floatsAboveFullScreen)
                }
                PanelPreview(side: store.panelSide, screen: store.settings.panelScreen ?? "Main display")
                    .frame(width: 244)
                    // Level with the group's box rather than its caps title.
                    .padding(.top, 39)
            }
            SettingsGroup(title: "POMODORO & BREAKS") {
                SettingsRow(
                    "Pomodoros", detail: "Work in sprints with a short break between each.", isOn: $store.isPomodoroOn)
                Group {
                    SettingsRow("Work sprint", isIndented: true) {
                        SettingsDurationStepper(
                            title: "Work sprint", length: $store.sprintLength, range: Self.sprintRange, step: 5)
                    }
                    SettingsRow("Break", isIndented: true) {
                        SettingsDurationStepper(
                            title: "Break", length: $store.breakLength, range: Self.breakRange, step: 1)
                    }
                }
                .opacity(store.isPomodoroOn ? 1 : 0.4)
                .disabled(!store.isPomodoroOn)
                SettingsRow(
                    "Default break",
                    detail: Text("Used by Start break ") + Text("⌘⌥B").font(Typography.kbd)
                        + Text(" when Pomodoros are off.")
                ) {
                    SettingsDurationStepper(
                        title: "Default break", length: $store.settings.defaultBreakLength, range: Self.breakRange,
                        step: 1)
                }
            }
            .environment(\.settingsTint, Palette.pink)
            SettingsGroup(title: "WHILE A TASK IS LIVE") {
                SettingsRow(
                    "Scrolling title", detail: "Long task titles scroll instead of cutting off.",
                    isOn: $store.settings.scrollsTitle)
                SettingsRow(
                    "Open links in notes when a task starts",
                    detail: "Docs and tickets from the task's notes open as it goes live.",
                    isOn: $store.settings.opensLinksOnStart)
            }
        }
    }

    /// Displays by name, as the system shows them; nil follows whichever display has the menu bar.
    private var screenOptions: [(value: String?, label: String)] {
        [(nil, "Main display")] + NSScreen.screens.map { (Optional($0.localizedName), $0.localizedName) }
    }
}

/// The PREVIEW card: a little display with the panel sliding to the chosen edge.
private struct PanelPreview: View {
    var side: BoardStore.PanelSide
    var screen: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        VStack(spacing: 10) {
            HStack {
                Text("PREVIEW").font(Typography.label).tracking(Typography.Tracking.label)
                    .foregroundStyle(Palette.textMuted)
                Spacer()
                Chip(side == .left ? "Left" : "Right", tint: .lime, size: .compact)
            }
            VStack(spacing: 0) {
                display
                StandShape()
                    .fill(LinearGradient(colors: [Palette.raised, Palette.bg], startPoint: .top, endPoint: .bottom))
                    .frame(width: 44, height: 10)
                Capsule().fill(Palette.raised).frame(width: 76, height: 3)
            }
            Text("\(side == .left ? "Left" : "Right") edge · \(screen)")
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.horizontal, Space.s4)
        .padding(.vertical, 14)
        .spotlight(Palette.lime, radius: Radius.card, lifts: false) {
            shape.fill(Palette.card).overlay(shape.strokeBorder(Palette.border))
        }
        .accessibilityElement(children: .combine)
    }

    private var display: some View {
        let frame = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return ZStack(alignment: side == .left ? .leading : .trailing) {
            frame.fill(Palette.bg)
                .overlay(
                    RadialGradient(
                        colors: [Palette.blue.opacity(0.22), .clear], center: UnitPoint(x: 0.2, y: 0),
                        startRadius: 0, endRadius: 150))
            VStack(spacing: 0) {
                Rectangle().fill(Color.black.opacity(0.5)).frame(height: 9)
                Spacer()
            }
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.white.opacity(0.08)))
                .frame(width: 108, height: 62)
                .frame(maxWidth: .infinity)
            dock
                .padding(.top, 16)
                .padding(.bottom, 7)
                .padding(.horizontal, 7)
        }
        .frame(width: 212, height: 132)
        .clipShape(frame)
        .overlay(frame.strokeBorder(Color.white.opacity(0.12)))
        .animation(reduceMotion ? nil : Motion.spring, value: side)
    }

    private var dock: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        return VStack(spacing: 5) {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Palette.lime, lineWidth: 2.5)
                .frame(width: 16, height: 16)
            ForEach([28.0, 28, 20, 24], id: \.self) { width in
                Capsule().fill(Color.white.opacity(0.35)).frame(width: width, height: 3)
            }
            Spacer()
        }
        .padding(.top, 9)
        .frame(width: 44)
        .frame(maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Palette.lime.opacity(0.3), Palette.teal.opacity(0.14)], startPoint: .top, endPoint: .bottom),
            in: shape
        )
        .overlay(shape.strokeBorder(Palette.lime.opacity(0.75)))
        .shadow(color: Palette.lime.opacity(0.6), radius: 9)
    }
}

/// The monitor stand under the preview display.
private struct StandShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.width * 0.18, y: 0))
            path.addLine(to: CGPoint(x: rect.width * 0.82, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
    }
}

#Preview("Focus") {
    ScrollView {
        SettingsFocusPage(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
            .padding(28)
    }
    .frame(width: 864, height: 760)
    .background(Palette.bg)
}
