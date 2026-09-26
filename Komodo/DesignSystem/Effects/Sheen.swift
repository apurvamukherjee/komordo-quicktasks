import SwiftUI

/// The diagonal light that sweeps across primary buttons every 3.6 s (DESIGN_SYSTEM §5).
/// Idle for the first 62% of each loop, then crosses on the house curve.
private struct Sheen: ViewModifier {
    var cornerRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let idleShare = 0.62
    private static let travel = 1.3
    private static let curve = UnitCurve.bezier(
        startControlPoint: UnitPoint(x: 0.2, y: 0.8),
        endControlPoint: UnitPoint(x: 0.2, y: 1)
    )

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                TimelineView(.animation) { context in
                    GeometryReader { geo in
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.3),
                                .init(color: .white.opacity(0.55), location: 0.5),
                                .init(color: .clear, location: 0.7),
                            ],
                            // CSS 110°: mostly left to right, tipping downward.
                            startPoint: UnitPoint(x: 0.03, y: 0.33),
                            endPoint: UnitPoint(x: 0.97, y: 0.67)
                        )
                        .offset(x: Self.position(at: context.date) * geo.size.width)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)
            }
        }
    }

    /// Horizontal offset as a fraction of the width, from −1.3 (off the leading edge) to +1.3.
    private static func position(at date: Date) -> CGFloat {
        let loop = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Motion.Period.sheen)
        let progress = loop / Motion.Period.sheen
        guard progress > idleShare else { return -travel }
        let sweep = curve.value(at: (progress - idleShare) / (1 - idleShare))
        return -travel + 2 * travel * sweep
    }
}

extension View {
    func sheen(cornerRadius: CGFloat) -> some View {
        modifier(Sheen(cornerRadius: cornerRadius))
    }
}

#Preview("Sheen") {
    Text("Start")
        .font(Typography.cardTitle)
        .foregroundStyle(Palette.onAccent)
        .padding(.horizontal, Space.s5)
        .padding(.vertical, Space.s3)
        .background(Palette.liveGradient, in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous))
        .sheen(cornerRadius: Radius.control)
        .padding(Space.s8 * 2)
        .background(Palette.bg)
}
