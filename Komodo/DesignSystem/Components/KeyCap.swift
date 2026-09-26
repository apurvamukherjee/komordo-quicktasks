import SwiftUI

/// A keyboard shortcut drawn as a key cap, e.g. `⌘⌥F`.
struct KeyCap: View {
    var keys: String
    var tint: Color?

    init(_ keys: String, tint: Color? = nil) {
        self.keys = keys
        self.tint = tint
    }

    private var textColor: Color { tint == nil ? Palette.textTertiary : Palette.limeText }
    private var fill: Color { tint?.opacity(0.1) ?? Color.white.opacity(0.07) }
    private var border: Color { tint?.opacity(0.2) ?? Color.white.opacity(0.08) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        Text(keys)
            .font(Typography.kbd)
            .foregroundStyle(textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(border, lineWidth: 1))
            .fixedSize()
            .accessibilityLabel("Shortcut \(keys)")
    }
}

#Preview("Key caps") {
    HStack(spacing: 6) {
        KeyCap("⌘⇧B")
        KeyCap("⌘⌥F done")
        KeyCap("N")
        KeyCap("⌘Z", tint: Palette.lime)
    }
    .padding(Space.s8)
    .background(Palette.bg)
}
