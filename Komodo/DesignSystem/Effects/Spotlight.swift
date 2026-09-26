import SwiftUI

/// Cursor spotlight (DESIGN_HANDOFF §4.1): a tinted fill glow and a 1 pt border light centred on the pointer.
///
/// The surface is drawn by the modifier so the glow can sit between the surface and the content, the way
/// the canvas layers it. A glow placed in `.background` of a view that already has an opaque fill would be hidden.
struct Spotlight<Surface: View>: ViewModifier {
    var tint: Color
    var radius: CGFloat
    var lifts: Bool
    var surface: Surface

    @State private var point: CGPoint?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let isLifted = point != nil && lifts
        content
            .background {
                ZStack {
                    surface
                    if let point {
                        GeometryReader { geo in
                            RadialGradient(
                                stops: [
                                    .init(color: tint.opacity(0.14), location: 0),
                                    .init(color: .clear, location: 0.62),
                                ],
                                center: Self.unit(point, in: geo.size), startRadius: 0, endRadius: 300)
                        }
                        .clipShape(shape)
                        .transition(.opacity)
                    }
                }
            }
            .overlay {
                if let point {
                    GeometryReader { geo in
                        shape.strokeBorder(
                            RadialGradient(
                                stops: [
                                    .init(color: tint.opacity(0.95), location: 0),
                                    .init(color: tint.opacity(0.22), location: 0.45),
                                    .init(color: .clear, location: 0.72),
                                ],
                                center: Self.unit(point, in: geo.size), startRadius: 0, endRadius: 220),
                            lineWidth: 1)
                    }
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }
            }
            // Scoped so the lift springs while the glow keeps its own 0.32 s fade.
            .animation(Motion.spring) { view in
                view
                    .offset(y: isLifted && !reduceMotion ? -3 : 0)
                    .shadow(color: isLifted ? tint.opacity(0.35) : .clear, radius: 24, y: 9)
            }
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let location):
                    if point == nil {
                        withAnimation(Motion.spotlightFade) { point = location }
                    } else {
                        // Tracking stays instant; only the fade in and out animates.
                        point = location
                    }
                case .ended:
                    withAnimation(Motion.spotlightFade) { point = nil }
                }
            }
    }

    private static func unit(_ point: CGPoint, in size: CGSize) -> UnitPoint {
        UnitPoint(
            x: size.width > 0 ? point.x / size.width : 0.5,
            y: size.height > 0 ? point.y / size.height : 0.5)
    }
}

extension View {
    /// For content whose surface is already translucent or absent. `lifts: false` for columns and stages,
    /// which light up but stay put.
    func spotlight(_ tint: Color, radius: CGFloat = Radius.card, lifts: Bool = true) -> some View {
        modifier(Spotlight(tint: tint, radius: radius, lifts: lifts, surface: EmptyView()))
    }

    func spotlight<Surface: View>(
        _ tint: Color, radius: CGFloat = Radius.card, lifts: Bool = true, @ViewBuilder surface: () -> Surface
    ) -> some View {
        modifier(Spotlight(tint: tint, radius: radius, lifts: lifts, surface: surface()))
    }
}

#Preview("Spotlight") {
    HStack(spacing: Space.columnGutter) {
        ForEach(
            [
                ("Today · lime", SpotlightTint.today),
                ("This week · blue", SpotlightTint.week),
                ("Backlog · violet", SpotlightTint.backlog),
            ], id: \.0
        ) { title, tint in
            Text(title)
                .font(Typography.heading)
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(22)
                .frame(height: 190)
                .spotlight(tint) { CardSurface() }
        }
    }
    .padding(Space.s8)
    .frame(width: 900)
    .background(Palette.bg)
}
