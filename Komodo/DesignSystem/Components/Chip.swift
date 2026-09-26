import SwiftUI

/// Tinted capsule labels: EST, schedule, due, repeat, outcomes, statuses (DESIGN_SYSTEM §2.3, §10.1).
struct Chip: View {
    enum Tint {
        case neutral
        /// No fill, a white 20% outline: Skipped, Paused, Offline, No event.
        case outline
        case lime
        case teal
        case blue
        case violet
        case amber
        case red
        case green
        case pink

        /// Text, fill and border. Accents use the lighter text step on a 12% fill (DESIGN_SYSTEM §2.2).
        var colors: (text: Color, fill: Color, border: Color) {
            switch self {
            case .neutral: (Palette.textTertiary, .white.opacity(0.05), .white.opacity(0.07))
            case .outline: (Palette.textSecondary, .clear, .white.opacity(0.2))
            case .lime: (Palette.limeText, Palette.lime.opacity(0.12), Palette.lime.opacity(0.3))
            case .teal: (Palette.tealText, Palette.teal.opacity(0.12), Palette.teal.opacity(0.3))
            case .blue: (Palette.blueText, Palette.blue.opacity(0.12), Palette.blue.opacity(0.3))
            case .violet: (Palette.violetText, Palette.violet.opacity(0.12), Palette.violet.opacity(0.28))
            case .amber: (Palette.amberText, Palette.amber.opacity(0.12), Palette.amber.opacity(0.3))
            case .red: (Palette.redText, Palette.danger.opacity(0.12), Palette.dangerLine.opacity(0.3))
            case .green: (Palette.greenText, Palette.green.opacity(0.12), Palette.green.opacity(0.28))
            case .pink: (Palette.pinkText, Palette.pink.opacity(0.1), Palette.pink.opacity(0.26))
            }
        }
    }

    enum Size {
        /// 24 pt, the card and row chip.
        case regular
        /// 20 pt, for chips inside a field, like a parsed estimate.
        case compact

        var height: CGFloat { self == .regular ? 24 : 20 }
    }

    var text: String
    var tint: Tint = .neutral
    var icon: String?
    var size: Size = .regular

    init(_ text: String, tint: Tint = .neutral, icon: String? = nil, size: Size = .regular) {
        self.text = text
        self.tint = tint
        self.icon = icon
        self.size = size
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
        let colors = tint.colors
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            }
            Text(text).lineLimit(1)
        }
        .font(Typography.small)
        .monospacedDigit()
        .foregroundStyle(colors.text)
        .padding(.horizontal, 9)
        .frame(height: size.height)
        .background(colors.fill, in: shape)
        .overlay(shape.strokeBorder(colors.border, lineWidth: 1))
        .fixedSize()
    }
}

/// EST presets under the quick-add field (`15m`, `30m`, `1h`): neutral until hovered, then lime.
struct PresetChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PresetChipBody(configuration: configuration)
    }
}

private struct PresetChipBody: View {
    var configuration: ButtonStyleConfiguration
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .font(Typography.small)
            .foregroundStyle(isHovered ? Palette.limeText : Palette.textTertiary)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(
                isHovered ? Palette.lime.opacity(0.16) : Color.white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .offset(y: isHovered ? -1 : 0)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(Motion.spring, value: isHovered)
            .animation(Motion.spring, value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}

extension ButtonStyle where Self == PresetChipButtonStyle {
    static var presetChip: PresetChipButtonStyle { PresetChipButtonStyle() }
}

#Preview("Chips") {
    VStack(alignment: .leading, spacing: Space.s3) {
        FlowLayout {
            Chip("2hr 30min", icon: "clock")
            Chip("Sun 10:00 AM", tint: .blue, icon: "calendar")
            Chip("Due Oct 10", tint: .amber, icon: "flag")
            Chip("Every Friday", tint: .violet, icon: "repeat")
            Chip("Overdue · 9:00 AM", tint: .red, icon: "clock")
            Chip("45min parsed", tint: .lime)
            Chip("Added", tint: .green)
            Chip("Review", tint: .amber)
            Chip("Skipped", tint: .outline)
            Chip("New", tint: .pink)
            Chip("Scanning", tint: .teal)
            Chip("45min", tint: .lime, size: .compact)
        }
        HStack(spacing: 6) {
            Button("15m") {}.buttonStyle(.presetChip)
            Button("30m") {}.buttonStyle(.presetChip)
            Button("1h") {}.buttonStyle(.presetChip)
        }
    }
    .frame(width: 520)
    .padding(Space.s8)
    .background(Palette.bg)
}
