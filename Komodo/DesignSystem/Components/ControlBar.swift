import SwiftUI

/// What the control bar's buttons do. The owner of the timer supplies these.
struct ControlBarActions {
    var takeBreak: () -> Void = {}
    var openNotes: () -> Void = {}
    var togglePause: () -> Void = {}
    var skip: () -> Void = {}
    var done: () -> Void = {}
    var addFive: () -> Void = {}
    var addFifteen: () -> Void = {}
    var next: () -> Void = {}
}

/// `Break · Notes · Pause · Skip · Done` as five equal 56 pt tiles, with exactly one primary per state
/// (DESIGN_SYSTEM §10.4). Time's Up swaps in `+5 min · +15 min · Done · Next`.
struct ControlBar: View {
    enum Mode {
        case running
        case paused
        case timesUp

        init(tone: TimerTone) {
            switch tone {
            case .timesUp: self = .timesUp
            case .paused: self = .paused
            case .live, .sprint, .onBreak: self = .running
            }
        }
    }

    var mode: Mode
    var actions: ControlBarActions
    /// 56 pt on the Board, 54 pt in the Focus Panel.
    var tileHeight: CGFloat = 56

    var body: some View {
        switch mode {
        case .running, .paused:
            WeightedHStack(weights: [1, 1, 1, 1, 1], spacing: 6) {
                tile("Break", "cup.and.saucer", help: "Break ⌘⌥B", action: actions.takeBreak)
                tile("Notes", "note.text", help: "Notes ⌘⌥N", action: actions.openNotes)
                tile(
                    mode == .running ? "Pause" : "Resume", mode == .running ? "pause" : "play",
                    kind: mode == .paused ? .primary : .standard, help: "Pause ⌘⌥P", action: actions.togglePause)
                tile("Skip", "forward.end", help: "Skip ⌘⌥S", action: actions.skip)
                tile(
                    "Done", "checkmark", kind: mode == .running ? .primary : .standard, help: "Done ⌘⌥F",
                    action: actions.done)
            }
        case .timesUp:
            WeightedHStack(weights: [1, 1, 1, 1], spacing: 6) {
                tile("+5 min", nil, kind: .danger, help: "Add 5 minutes", action: actions.addFive)
                tile("+15 min", nil, kind: .danger, help: "Add 15 minutes", action: actions.addFifteen)
                tile("Done", "checkmark", kind: .primary, help: "Done ⌘⌥F", action: actions.done)
                tile("Next", nil, help: "Next task", action: actions.next)
            }
        }
    }

    private func tile(
        _ title: String, _ symbol: String?, kind: ControlTileStyle.Kind = .standard, help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 15, weight: .medium))
                }
                Text(title)
            }
        }
        .buttonStyle(ControlTileStyle(kind: kind, height: tileHeight))
        .help(help)
    }
}

struct ControlTileStyle: ButtonStyle {
    enum Kind {
        case standard
        /// Live gradient with the sheen.
        case primary
        /// The Time's Up extensions.
        case danger
    }

    var kind: Kind
    var height: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        ControlTileBody(configuration: configuration, kind: kind, height: height)
    }
}

private struct ControlTileBody: View {
    var configuration: ButtonStyleConfiguration
    var kind: ControlTileStyle.Kind
    var height: CGFloat

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        configuration.label
            .font(.system(size: 11, weight: kind == .primary ? .bold : .semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background { fill(shape) }
            .overlay(shape.strokeBorder(border, lineWidth: 1))
            .overlay { if kind == .primary { Color.clear.sheen(cornerRadius: Radius.tile) } }
            .shadow(color: kind == .primary ? Palette.lime.opacity(0.5) : .clear, radius: 11, y: 8)
            .contentShape(shape)
            .offset(y: isHovered && !configuration.isPressed ? -2 : 0)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(Motion.spring, value: configuration.isPressed)
            .animation(Motion.spring, value: isHovered)
            .onHover { isHovered = $0 }
    }

    private var foreground: Color {
        switch kind {
        case .standard: Palette.textBody
        case .primary: Palette.onAccent
        case .danger: Palette.redText
        }
    }

    private var border: Color {
        switch kind {
        case .standard: Color.white.opacity(isHovered ? 0.16 : 0.07)
        case .primary: Palette.limeText.opacity(0.6)
        case .danger: Palette.dangerLine.opacity(0.4)
        }
    }

    @ViewBuilder private func fill(_ shape: RoundedRectangle) -> some View {
        switch kind {
        case .standard: shape.fill(Color.white.opacity(isHovered ? 0.1 : 0.045))
        case .primary:
            shape.fill(
                LinearGradient(
                    colors: [Palette.teal, Palette.lime], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .brightness(isHovered ? 0.06 : 0)
        case .danger: shape.fill(Palette.danger.opacity(isHovered ? 0.2 : 0.14))
        }
    }
}

#Preview("Control bar") {
    VStack(spacing: Space.s4) {
        ControlBar(mode: .running, actions: ControlBarActions())
        ControlBar(mode: .paused, actions: ControlBarActions())
        ControlBar(mode: .timesUp, actions: ControlBarActions())
    }
    .frame(width: 440)
    .padding(Space.s8)
    .background(Palette.bg)
}
