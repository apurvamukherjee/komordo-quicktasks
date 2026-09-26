import SwiftUI

/// The material of every card and tile (DESIGN_SYSTEM §10.1): a subtle top-lit gradient, a 1 pt
/// hairline, and a 1 pt inner highlight along the top edge.
///
/// A view rather than a modifier so `.spotlight(tint) { CardSurface() }` can slide its glow between
/// the surface and the content.
struct CardSurface: View {
    var radius: CGFloat = Radius.card
    /// Replaces the gradient for flat variants (dragged card on `raised`, done card on `panel`).
    var fill: Color?

    private static let highlightOpacity = 0.045
    private static let highlightDepth = 0.2

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            if let fill {
                shape.fill(fill)
            } else {
                shape.fill(
                    LinearGradient(colors: [Palette.cardTop, Palette.card], startPoint: .top, endPoint: .bottom))
            }
            shape.strokeBorder(Palette.border, lineWidth: 1)
            // Only the top of an inset ring shows, which reads as light catching the upper edge.
            shape
                .inset(by: 1)
                .strokeBorder(Color.white.opacity(Self.highlightOpacity), lineWidth: 1)
                .mask(
                    LinearGradient(
                        colors: [.white, .clear],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: Self.highlightDepth)
                    )
                )
        }
        .allowsHitTesting(false)
    }
}

/// Neutral tiles inside sections: white 3.5% over whatever sits behind, with a hairline edge.
struct TileSurface: View {
    var radius: CGFloat = Radius.tile

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape.fill(Color.white.opacity(0.035))
            .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
            .allowsHitTesting(false)
    }
}

extension View {
    /// For surfaces that never light up. Anything interactive uses `.spotlight(tint) { CardSurface() }`.
    func cardSurface(radius: CGFloat = Radius.card) -> some View {
        background { CardSurface(radius: radius) }
    }
}

#Preview("CardSurface") {
    HStack(spacing: Space.s6) {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text("Review accounts").font(Typography.cardTitle).foregroundStyle(Palette.textPrimary)
            Text("2hr 30min").font(Typography.small).foregroundStyle(Palette.textTertiary)
        }
        .padding(Space.s4)
        .frame(width: 280, alignment: .leading)
        .spotlight(SpotlightTint.today) { CardSurface() }

        Text("Tile")
            .font(Typography.small)
            .foregroundStyle(Palette.textSecondary)
            .padding(Space.s4)
            .frame(width: 160, alignment: .leading)
            .spotlight(SpotlightTint.info, radius: Radius.tile, lifts: false) { TileSurface() }
    }
    .padding(Space.s8 * 2)
    .background(Palette.bg)
}
