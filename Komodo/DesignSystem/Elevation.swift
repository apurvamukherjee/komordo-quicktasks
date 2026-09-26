import SwiftUI

// Shadows and glows from DESIGN_SYSTEM §4.2. On a true-black canvas, separation comes mostly from
// surface steps; these add depth for lifted, floating and dragged things and a halo for live states.
enum Elevation {
    enum Glow {
        static let liveOpacity = 0.75
        static let breakOpacity = 0.75
        static let dangerOpacity = 0.8
        static let radius: CGFloat = 22
    }

    enum Lift {
        static let dropOpacity = 0.95
        static let dropRadius: CGFloat = 22
        static let dropY: CGFloat = 12
        // DESIGN_SYSTEM says 75%, but SwiftUI shadows have no negative spread like the canvas CSS,
        // so 75% floods the surroundings. 35% (DESIGN_HANDOFF §4.1) matches the canvas.
        static let tintOpacity = 0.35
        static let tintRadius: CGFloat = 24
        static let tintY: CGFloat = 9
    }

    enum Float {
        static let opacity = 0.9
        static let radius: CGFloat = 30
        static let y: CGFloat = 12
        static let strokeOpacity = 0.1
    }

    enum Drag {
        static let radius: CGFloat = 25
        static let y: CGFloat = 15
        static let glowOpacity = 0.45
        static let glowRadius: CGFloat = 22
        static let tilt = Angle.degrees(-2.5)
        static let scale = 1.03
    }
}

extension View {
    func glowLive() -> some View {
        shadow(color: Palette.lime.opacity(Elevation.Glow.liveOpacity), radius: Elevation.Glow.radius)
    }

    func glowBreak() -> some View {
        shadow(color: Palette.green.opacity(Elevation.Glow.breakOpacity), radius: Elevation.Glow.radius)
    }

    func glowDanger() -> some View {
        shadow(color: Palette.danger.opacity(Elevation.Glow.dangerOpacity), radius: Elevation.Glow.radius)
    }

    /// Hovered cards: a deep drop plus a glow in the card's spotlight tint.
    func shadowLift(_ tint: Color, isActive: Bool = true) -> some View {
        self
            .shadow(
                color: isActive ? .black.opacity(Elevation.Lift.dropOpacity) : .clear,
                radius: Elevation.Lift.dropRadius,
                y: Elevation.Lift.dropY
            )
            .shadow(
                color: isActive ? tint.opacity(Elevation.Lift.tintOpacity) : .clear,
                radius: Elevation.Lift.tintRadius,
                y: Elevation.Lift.tintY
            )
    }

    /// Popovers, menus, the floating timer and sheets.
    func shadowFloat(cornerRadius: CGFloat) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(Elevation.Float.strokeOpacity), lineWidth: 1)
        }
        .shadow(color: .black.opacity(Elevation.Float.opacity), radius: Elevation.Float.radius, y: Elevation.Float.y)
    }

    /// The card being dragged: lifted, tilted and glowing lime.
    func shadowDrag() -> some View {
        self
            .shadow(color: .black, radius: Elevation.Drag.radius, y: Elevation.Drag.y)
            .shadow(color: Palette.lime.opacity(Elevation.Drag.glowOpacity), radius: Elevation.Drag.glowRadius)
            .rotationEffect(Elevation.Drag.tilt)
            .scaleEffect(Elevation.Drag.scale)
    }
}

#Preview("Elevation") {
    let tile = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
    HStack(spacing: Space.s8) {
        tile.fill(Palette.card).frame(width: 58, height: 58).glowLive()
        tile.fill(Palette.card).frame(width: 58, height: 58).glowBreak()
        tile.fill(Palette.card).frame(width: 58, height: 58).glowDanger()
        tile.fill(Palette.card).frame(width: 58, height: 58).shadowLift(Palette.lime)
        tile.fill(Palette.raised).frame(width: 58, height: 58).shadowFloat(cornerRadius: Radius.card)
        tile.fill(Palette.raised).frame(width: 58, height: 58).shadowDrag()
    }
    .padding(Space.s8 * 2)
    .background(Palette.bg)
}
