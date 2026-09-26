import SwiftUI

extension View {
    /// Custom popovers and menus (the canvas's `.k-pop`): translucent raised glass with a hairline, a top
    /// highlight and `.shadowFloat()`, lit by the spotlight like every other surface.
    func popoverSurface(tint: Color = SpotlightTint.info) -> some View {
        spotlight(tint, radius: Radius.tile, lifts: false) { PopoverGlass() }
            .shadowFloat(cornerRadius: Radius.tile)
    }
}

private struct PopoverGlass: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(Palette.raised.opacity(0.94))
            shape.strokeBorder(
                LinearGradient(
                    stops: [.init(color: .white.opacity(0.06), location: 0), .init(color: .clear, location: 0.1)],
                    startPoint: .top, endPoint: .bottom),
                lineWidth: 1)
        }
    }
}

#Preview("Popover surface") {
    VStack(alignment: .leading, spacing: 2) {
        ForEach(["Move to Today", "Schedule…", "Repeat…", "Delete"], id: \.self) { item in
            Text(item)
                .font(Typography.body)
                .foregroundStyle(item == "Delete" ? Palette.dangerText : Palette.textPrimary)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
        }
    }
    .padding(6)
    .frame(width: 220)
    .popoverSurface()
    .padding(48)
    .background(Palette.bg)
}
