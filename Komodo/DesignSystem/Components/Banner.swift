import SwiftUI

/// A 36 pt message above the Home window's content (DESIGN_SYSTEM §10.9, §14.4). Danger stays until it's
/// fixed or closed, warning's action is its dismissal, and info offers an update.
struct Banner: View {
    enum Tone {
        case danger
        case warning
        case info

        var symbol: String {
            switch self {
            case .danger: "exclamationmark.triangle.fill"
            case .warning: "wifi.slash"
            case .info: "arrow.down.circle.fill"
            }
        }

        var accent: Color {
            switch self {
            case .danger: Palette.danger
            case .warning: Palette.amber
            case .info: Palette.blue
            }
        }

        var text: Color {
            switch self {
            case .danger: Palette.bannerDangerText
            case .warning: Palette.bannerWarningText
            case .info: Palette.bannerInfoText
            }
        }

        var border: Color {
            switch self {
            case .danger: Palette.dangerLine.opacity(0.32)
            case .warning: Palette.amber.opacity(0.3)
            case .info: Palette.blue.opacity(0.32)
            }
        }

        var fillOpacity: Double {
            switch self {
            case .danger: 0.12
            case .warning: 0.1
            case .info: 0.11
            }
        }
    }

    struct Action {
        var title: String
        var perform: () -> Void
    }

    var tone: Tone
    var message: String
    var symbol: String?
    var action: Action?
    var onClose: (() -> Void)?
    /// Full-bleed under the toolbar: square corners and only a bottom hairline.
    var isEdgeToEdge = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol ?? tone.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tone.accent)
            Text(message)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(tone.text)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let action {
                Button(action.title, action: action.perform).buttonStyle(BannerActionStyle(tone: tone))
            }
            if let onClose {
                Button("Close banner", systemImage: "xmark", action: onClose).buttonStyle(.icon(.compact))
            }
        }
        .padding(.leading, Space.s3)
        .padding(.trailing, 6)
        .frame(height: 36)
        .spotlight(tone.accent, radius: isEdgeToEdge ? 0 : Radius.control, lifts: false) { surface }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var surface: some View {
        if isEdgeToEdge {
            Rectangle()
                .fill(tone.accent.opacity(tone.fillOpacity))
                .overlay(alignment: .bottom) { Rectangle().fill(tone.border).frame(height: 1) }
        } else {
            let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
            shape.fill(tone.accent.opacity(tone.fillOpacity))
                .overlay(shape.strokeBorder(tone.border, lineWidth: 1))
        }
    }
}

private struct BannerActionStyle: ButtonStyle {
    var tone: Banner.Tone

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(outline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(Motion.spring, value: configuration.isPressed)
    }

    private var foreground: Color {
        switch tone {
        case .danger: Palette.onAccent
        case .warning: Palette.amberText
        case .info: Palette.blueText
        }
    }

    private var fill: Color {
        switch tone {
        case .danger: Palette.danger
        case .warning: Palette.amber.opacity(0.16)
        case .info: Palette.blue.opacity(0.2)
        }
    }

    private var outline: Color {
        switch tone {
        case .danger: .clear
        case .warning: Palette.amber.opacity(0.36)
        case .info: Palette.blue.opacity(0.45)
        }
    }
}

#Preview("Banners") {
    VStack(spacing: Space.s3) {
        Banner(
            tone: .danger, message: "Google disconnected. Reconnect to keep adding events.",
            action: .init(title: "Reconnect") {}, onClose: {})
        Banner(
            tone: .warning,
            message: "You're offline. Everything still works, and Gmail will catch up when you're back.",
            action: .init(title: "Dismiss") {})
        Banner(
            tone: .info, message: "Komodo 1.1 is ready.", action: .init(title: "Install and Relaunch") {},
            onClose: {})
        Banner(
            tone: .danger, message: "Google disconnected. Reconnect to keep adding events.",
            action: .init(title: "Reconnect") {}, onClose: {}, isEdgeToEdge: true)
    }
    .frame(width: 640)
    .padding(Space.s8)
    .background(Palette.bg)
}
