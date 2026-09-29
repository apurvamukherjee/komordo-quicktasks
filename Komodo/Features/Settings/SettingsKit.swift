import KomodoCore
import SwiftUI

extension EnvironmentValues {
    /// The current page's spotlight, so every group on it lights up in the same color.
    @Entry var settingsTint: Color = SpotlightTint.info
}

/// `.st-gh` + `.st-g`: a small caps title over a rounded group of rows, lit by the page's spotlight. Rows draw a
/// hairline under themselves; the group clips the last one away.
struct SettingsGroup<Content: View>: View {
    var title: String
    /// Data & backup's danger zone: a red title, spotlight and edge.
    var isDanger = false
    @ViewBuilder var content: Content

    @Environment(\.settingsTint) private var tint

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(Typography.label)
                .tracking(Typography.Tracking.label)
                .foregroundStyle(isDanger ? Palette.dangerText : Palette.textMuted)
                .padding(.horizontal, Space.s1)
                .padding(.top, 18)
                .padding(.bottom, Space.s2)
            VStack(spacing: 0) { content }
                .padding(.bottom, -1)
                .clipShape(shape)
                .spotlight(isDanger ? Palette.danger : tint, radius: Radius.tile, lifts: false) {
                    SettingsGroupSurface(isDanger: isDanger)
                }
        }
    }
}

/// White 3.5% fading to 2%, a hairline and a faint top highlight; red 6% to 2% with a red edge for danger.
struct SettingsGroupSurface: View {
    var isDanger = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        let fill = isDanger ? Palette.danger : Color.white
        shape
            .fill(
                LinearGradient(
                    colors: [fill.opacity(isDanger ? 0.06 : 0.035), fill.opacity(0.02)], startPoint: .top,
                    endPoint: .bottom)
            )
            .overlay(shape.strokeBorder(isDanger ? Palette.dangerLine.opacity(0.22) : Palette.border, lineWidth: 1))
            .allowsHitTesting(false)
    }
}

/// `.st-r`: a 13.5 pt title with an optional muted line under it, and the control trailing.
struct SettingsRow<Control: View>: View {
    var title: String
    var detail: Text?
    /// `.st-sub`: rows that belong to the switch above them sit 34 pt further in.
    var isIndented = false
    @ViewBuilder var control: Control

    init(_ title: String, detail: String? = nil, isIndented: Bool = false, @ViewBuilder control: () -> Control) {
        self.title = title
        self.detail = detail.map { Text($0) }
        self.isIndented = isIndented
        self.control = control()
    }

    init(_ title: String, detail: Text, isIndented: Bool = false, @ViewBuilder control: () -> Control) {
        self.title = title
        self.detail = detail
        self.isIndented = isIndented
        self.control = control()
    }

    var body: some View {
        HStack(spacing: Space.s4) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Palette.textBody)
                if let detail {
                    detail
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: Space.s2) { control }
                .fixedSize()
        }
        .padding(.leading, isIndented ? 50 : Space.s4)
        .padding(.trailing, Space.s4)
        .padding(.vertical, 11)
        .frame(minHeight: 56)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

extension SettingsRow where Control == SettingsSwitch {
    /// The most common row: a title, its line and a switch.
    init(_ title: String, detail: String? = nil, isIndented: Bool = false, isOn: Binding<Bool>) {
        self.init(title, detail: detail, isIndented: isIndented) { SettingsSwitch(title: title, isOn: isOn) }
    }
}

struct SettingsSwitch: View {
    var title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn).labelsHidden().komodoSwitch()
    }
}

/// `.st-pick`: the current choice and an up-down chevron in a 28 pt field over a native menu, which keeps the
/// checkmark on the current choice.
struct SettingsMenuPicker<Value: Hashable>: View {
    var title: String
    @Binding var selection: Value
    var options: [(value: Value, label: String)]

    @State private var isHovered = false

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            let shape = RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
            HStack(spacing: Space.s2) {
                Text(options.first { $0.value == selection }?.label ?? "")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.leading, 11)
            .padding(.trailing, Space.s2)
            .frame(height: 28)
            .background(Color.white.opacity(isHovered ? 0.1 : 0.07), in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(isHovered ? 0.16 : 0.1), lineWidth: 1))
            .contentShape(shape)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { isHovered = $0 }
        .animation(Motion.fast, value: isHovered)
        .accessibilityLabel(title)
    }
}

/// `.st-dur`: − 25:00 + and "min", stepping within the canvas's range.
struct SettingsDurationStepper: View {
    var title: String
    @Binding var length: TimeInterval
    var range: ClosedRange<Int>
    var step: Int

    var body: some View {
        let minutes = Int(length / 60)
        let set: (Int) -> Void = { length = TimeInterval(min(range.upperBound, max(range.lowerBound, $0)) * 60) }
        let shape = RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
        HStack(spacing: Space.s1) {
            HStack(spacing: 0) {
                stepButton("Shorter", symbol: "minus") { set(minutes - step) }
                    .disabled(minutes <= range.lowerBound)
                // Minutes as "25:00" and "90:00", as the canvas writes them, never "1:30:00".
                Text((minutes < 10 ? "0" : "") + "\(minutes):00")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 56)
                stepButton("Longer", symbol: "plus") { set(minutes + step) }
                    .disabled(minutes >= range.upperBound)
            }
            .padding(.horizontal, 1)
            .frame(height: 28)
            .background(Color.white.opacity(0.04), in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
            Text("min").font(.system(size: 11.5)).foregroundStyle(Palette.textMuted).padding(.leading, 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) in minutes")
        .accessibilityValue("\(minutes)")
        .accessibilityAdjustableAction { direction in
            set(direction == .increment ? minutes + step : minutes - step)
        }
    }

    private func stepButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(title, systemImage: symbol, action: action)
            .labelStyle(.iconOnly)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Palette.textSecondary)
            .frame(width: 24, height: 26)
            .contentShape(Rectangle())
            .buttonStyle(.plain)
    }
}

/// A round ▶ that plays a sound once, lit while it plays (`.st-play-on`).
struct SoundPreviewButton: View {
    var title: String
    var play: () -> Void

    @State private var isPlaying = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
        Button(title, systemImage: isPlaying ? "waveform" : "play.fill") {
            play()
            isPlaying = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                isPlaying = false
            }
        }
        .labelStyle(.iconOnly)
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(isPlaying ? Palette.limeText : Palette.textSecondary)
        .frame(width: 28, height: 28)
        .background(isPlaying ? Palette.lime.opacity(0.16) : Color.white.opacity(0.06), in: shape)
        .overlay(shape.strokeBorder(isPlaying ? Palette.lime.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1))
        .contentShape(shape)
        .buttonStyle(.plain)
        .animation(Motion.fast, value: isPlaying)
        .help(title)
    }
}
