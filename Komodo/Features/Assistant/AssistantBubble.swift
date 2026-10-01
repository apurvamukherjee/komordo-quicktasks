import SwiftUI

/// The Assistant's way in (DESIGN_SYSTEM §13.26): a 40 pt lime bubble at the bottom right, with the popover above
/// it. ⌘J opens and closes it from anywhere in the Home window.
struct AssistantHost: View {
    @Bindable var store: BoardStore

    var body: some View {
        let model = store.assistant
        VStack(alignment: .trailing, spacing: Space.s3) {
            if model.isOpen {
                AssistantPanel(store: store)
                    .transition(.scale(scale: 0.96, anchor: .bottomTrailing).combined(with: .opacity))
            }
            AssistantBubble(isOpen: model.isOpen) { model.isOpen.toggle() }
        }
        .animation(Motion.base, value: model.isOpen)
    }
}

struct AssistantBubble: View {
    var isOpen: Bool
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: isOpen ? "xmark" : "sparkles")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.onAccent)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 40, height: 40)
                .background(
                    RadialGradient(
                        colors: [Palette.limeText, Palette.lime], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0,
                        endRadius: 26),
                    in: Circle()
                )
                .shadow(color: Palette.lime.opacity(isHovered ? 0.7 : 0.45), radius: isHovered ? 14 : 10)
                .scaleEffect(isHovered ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(Motion.fast, value: isHovered)
        .keyboardShortcut("j", modifiers: .command)
        .help(isOpen ? "Close the Assistant (⌘J)" : "Assistant (⌘J)")
        .accessibilityLabel(isOpen ? "Close the Assistant" : "Assistant")
    }
}

#Preview("Assistant bubble") {
    HStack(spacing: Space.s6) {
        AssistantBubble(isOpen: false) {}
        AssistantBubble(isOpen: true) {}
    }
    .padding(Space.s8)
    .background(Palette.bg)
}
