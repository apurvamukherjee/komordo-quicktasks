import SwiftUI

/// Bare icon buttons in toolbars and rows (DESIGN_SYSTEM §9): muted symbol, a soft fill on hover.
struct IconButtonStyle: ButtonStyle {
    enum Size {
        /// 30 pt, 13 pt symbol: toolbars and headers (the canvas's `.k-icon`).
        case regular
        /// 24 pt, 12 pt symbol: dense rows, toasts and banners.
        case compact

        var side: CGFloat { self == .regular ? 30 : 24 }
        var symbol: CGFloat { self == .regular ? 13 : 12 }
        var radius: CGFloat { self == .regular ? 9 : 7 }
    }

    var size: Size = .regular
    var isToggled = false

    func makeBody(configuration: Configuration) -> some View {
        IconButtonBody(configuration: configuration, size: size, isToggled: isToggled)
    }
}

private struct IconButtonBody: View {
    var configuration: ButtonStyleConfiguration
    var size: IconButtonStyle.Size
    var isToggled: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        let lit = isHovered || isToggled
        configuration.label
            .labelStyle(.iconOnly)
            .font(.system(size: size.symbol, weight: .medium))
            .foregroundStyle(lit ? Palette.textPrimary : Palette.textSecondary)
            .frame(width: size.side, height: size.side)
            .background(
                Color.white.opacity(lit ? 0.08 : 0),
                in: RoundedRectangle(cornerRadius: size.radius, style: .continuous)
            )
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(Motion.spring, value: configuration.isPressed)
            .animation(Motion.fast, value: lit)
            .onHover { isHovered = $0 && isEnabled }
    }
}

/// The 30 pt action buttons that slide in on a hovered card (the canvas's `.k-act`). The `go` variant is the
/// bolt: it turns lime on hover because it makes the task live.
struct CardActionButtonStyle: ButtonStyle {
    var isGo = false

    func makeBody(configuration: Configuration) -> some View {
        CardActionBody(configuration: configuration, isGo: isGo)
    }
}

private struct CardActionBody: View {
    var configuration: ButtonStyleConfiguration
    var isGo: Bool

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        let lime = isGo && isHovered
        configuration.label
            .labelStyle(.iconOnly)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(lime ? Palette.onAccent : isHovered ? Palette.textPrimary : Palette.textTertiary)
            .frame(width: 30, height: 30)
            .background(lime ? Palette.lime : Color.white.opacity(isHovered ? 0.14 : 0.06), in: shape)
            .overlay(shape.strokeBorder(lime ? Palette.lime : Color.white.opacity(0.08), lineWidth: 1))
            .shadow(color: lime ? Palette.lime.opacity(0.8) : .clear, radius: 9)
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.9 : isHovered ? 1.1 : 1)
            .animation(Motion.spring, value: configuration.isPressed)
            .animation(Motion.spring, value: isHovered)
            .onHover { isHovered = $0 }
    }
}

extension ButtonStyle where Self == IconButtonStyle {
    static func icon(_ size: IconButtonStyle.Size = .regular, isToggled: Bool = false) -> IconButtonStyle {
        IconButtonStyle(size: size, isToggled: isToggled)
    }
}

extension ButtonStyle where Self == CardActionButtonStyle {
    static var cardAction: CardActionButtonStyle { CardActionButtonStyle() }
    static var cardActionGo: CardActionButtonStyle { CardActionButtonStyle(isGo: true) }
}

#Preview("Icon buttons") {
    HStack(spacing: Space.s3) {
        Button("Search", systemImage: "magnifyingglass") {}.buttonStyle(.icon())
        Button("Sidebar", systemImage: "sidebar.left") {}.buttonStyle(.icon(isToggled: true))
        Button("Dismiss", systemImage: "xmark") {}.buttonStyle(.icon(.compact))
        Divider().frame(height: 24)
        Button("Schedule", systemImage: "calendar.badge.clock") {}.buttonStyle(.cardAction)
        Button("Subtasks", systemImage: "checklist") {}.buttonStyle(.cardAction)
        Button("Notes", systemImage: "note.text") {}.buttonStyle(.cardAction)
        Button("Make live", systemImage: "bolt.fill") {}.buttonStyle(.cardActionGo)
    }
    .padding(Space.s8)
    .background(Palette.bg)
}
