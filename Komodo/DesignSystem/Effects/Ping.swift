import SwiftUI

/// A ring that swells out of a status dot and fades, on a 1.6 s loop (DESIGN_SYSTEM §5: scanning,
/// the live dot). Off under Reduce Motion.
private struct Ping: ViewModifier {
    var color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let startOpacity = 0.7
    private static let endScale = 2.8
    private static let curve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.2, y: 0.8),
        endControlPoint: UnitPoint(x: 0.2, y: 1)
    )

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                TimelineView(.animation) { context in
                    let loop = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: Motion.Period.ping)
                    let progress = Self.curve.value(at: loop / Motion.Period.ping)
                    Circle()
                        .fill(color)
                        .scaleEffect(1 + (Self.endScale - 1) * progress)
                        .opacity(Self.startOpacity * (1 - progress))
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
    }
}

extension View {
    func ping(_ color: Color) -> some View {
        modifier(Ping(color: color))
    }
}

#Preview("Ping") {
    HStack(spacing: Space.s6) {
        ForEach([Palette.lime, Palette.teal, Palette.green], id: \.self) { color in
            Circle().fill(color).frame(width: 7, height: 7).ping(color)
        }
    }
    .padding(Space.s8 * 2)
    .background(Palette.bg)
}
