import SwiftUI

/// Komodo's text buttons (DESIGN_SYSTEM §10.7), with the canvas's sizes: small 28, regular 34, large 40.
struct KomodoButtonStyle: ButtonStyle {
    enum Kind {
        /// Live gradient with the sheen. One per state.
        case primary
        /// White 5% with a hairline: Schedule, Skip break.
        case secondary
        case ghost
        case danger
        /// Danger text on a faint red fill: Empty Trash, Reconnect.
        case dangerOutline
    }

    enum Size {
        case small
        case regular
        case large

        var height: CGFloat {
            switch self {
            case .small: 28
            case .regular: 34
            case .large: 40
            }
        }

        var radius: CGFloat {
            switch self {
            case .small: Radius.chip
            case .regular: Radius.control
            case .large: Radius.control + 2
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: 10
            case .regular: 14
            case .large: 20
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: 12
            case .regular: 13
            case .large: 14
            }
        }
    }

    var kind: Kind = .secondary
    var size: Size = .regular
    /// Swaps the icon for a spinner and ignores clicks, e.g. while an export runs.
    var isBusy = false

    func makeBody(configuration: Configuration) -> some View {
        KomodoButtonBody(configuration: configuration, kind: kind, size: size, isBusy: isBusy)
    }
}

extension ButtonStyle where Self == KomodoButtonStyle {
    static func komodo(
        _ kind: KomodoButtonStyle.Kind = .secondary, size: KomodoButtonStyle.Size = .regular, isBusy: Bool = false
    ) -> KomodoButtonStyle {
        KomodoButtonStyle(kind: kind, size: size, isBusy: isBusy)
    }
}

private struct KomodoButtonBody: View {
    var configuration: ButtonStyleConfiguration
    var kind: KomodoButtonStyle.Kind
    var size: KomodoButtonStyle.Size
    var isBusy: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private var isBold: Bool { kind == .primary || kind == .danger || kind == .dangerOutline }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size.radius, style: .continuous)
        HStack(spacing: 7) {
            if isBusy {
                ProgressView().controlSize(.mini).tint(foreground)
            }
            configuration.label
                .labelStyle(BusyAwareLabelStyle(hidesIcon: isBusy))
        }
        .font(.system(size: size.fontSize, weight: isBold ? .bold : .semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, size.horizontalPadding)
        .frame(height: size.height)
        .background { fill(shape) }
        .overlay { stroke(shape) }
        .overlay {
            if kind == .primary && isEnabled { Color.clear.sheen(cornerRadius: size.radius) }
        }
        .contentShape(shape)
        .brightness(isHovered && (kind == .primary || kind == .danger) ? 0.06 : 0)
        .shadow(color: glow, radius: isHovered ? 14 : 10, y: 6)
        .opacity(isEnabled ? 1 : 0.4)
        .offset(y: isHovered && !configuration.isPressed ? -1 : 0)
        .scaleEffect(configuration.isPressed ? 0.95 : 1)
        .animation(Motion.spring, value: configuration.isPressed)
        .animation(Motion.fast, value: isHovered)
        .onHover { isHovered = $0 && isEnabled }
        .allowsHitTesting(!isBusy)
    }

    private var foreground: Color {
        switch kind {
        case .primary, .danger: Palette.onAccent
        case .secondary: Palette.textPrimary
        case .ghost: isHovered ? Palette.textPrimary : Palette.textTertiary
        case .dangerOutline: Palette.dangerText
        }
    }

    private var glow: Color {
        switch kind {
        case .primary: Palette.lime.opacity(isHovered ? 0.5 : 0.35)
        case .danger: Palette.danger.opacity(0.35)
        case .secondary, .ghost, .dangerOutline: .clear
        }
    }

    @ViewBuilder private func fill(_ shape: RoundedRectangle) -> some View {
        switch kind {
        case .primary:
            shape.fill(
                LinearGradient(
                    colors: [Palette.teal, Palette.lime], startPoint: .topLeading, endPoint: .bottomTrailing))
        case .secondary: shape.fill(Color.white.opacity(isHovered ? 0.1 : 0.05))
        case .ghost: shape.fill(Color.white.opacity(isHovered ? 0.07 : 0))
        case .danger: shape.fill(Palette.danger)
        case .dangerOutline: shape.fill(Palette.danger.opacity(isHovered ? 0.14 : 0.06))
        }
    }

    @ViewBuilder private func stroke(_ shape: RoundedRectangle) -> some View {
        switch kind {
        case .primary: shape.strokeBorder(Palette.limeText.opacity(isHovered ? 0.7 : 0.45), lineWidth: 1)
        case .secondary: shape.strokeBorder(Color.white.opacity(isHovered ? 0.16 : 0.09), lineWidth: 1)
        case .dangerOutline: shape.strokeBorder(Palette.dangerLine.opacity(0.35), lineWidth: 1)
        case .ghost, .danger: EmptyView()
        }
    }
}

/// While busy the spinner stands in for the icon, so the button keeps its width and title.
private struct BusyAwareLabelStyle: LabelStyle {
    var hidesIcon: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 7) {
            if !hidesIcon {
                configuration.icon.imageScale(.small)
            }
            configuration.title
        }
    }
}

#Preview("Buttons") {
    VStack(alignment: .leading, spacing: Space.s4) {
        HStack(spacing: 10) {
            Button("Start", systemImage: "play.fill") {}.buttonStyle(.komodo(.primary, size: .large))
            Button("Schedule") {}.buttonStyle(.komodo(.secondary, size: .large))
            Button("Cancel") {}.buttonStyle(.komodo(.ghost, size: .large))
            Button("Delete all") {}.buttonStyle(.komodo(.danger, size: .large))
            Button("Empty Trash") {}.buttonStyle(.komodo(.dangerOutline, size: .large))
        }
        HStack(spacing: 10) {
            Button("sm 28") {}.buttonStyle(.komodo(.primary, size: .small))
            Button("md 34") {}.buttonStyle(.komodo(.primary))
            Button("lg 40") {}.buttonStyle(.komodo(.primary, size: .large))
            Button("Disabled") {}.buttonStyle(.komodo()).disabled(true)
            Button("Export zip", systemImage: "square.and.arrow.up") {}.buttonStyle(.komodo(isBusy: true))
        }
    }
    .padding(Space.s8)
    .background(Palette.bg)
}
