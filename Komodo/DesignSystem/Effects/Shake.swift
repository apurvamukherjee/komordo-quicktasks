import SwiftUI

/// Time's Up shake (DESIGN_SYSTEM §5): two ±4 pt swings of 0.3 s each, whenever `trigger` changes.
private struct Shake<Trigger: Equatable & Sendable>: ViewModifier {
    var trigger: Trigger
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static var swing: CGFloat { 4 }

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.keyframeAnimator(initialValue: CGFloat.zero, trigger: trigger) { view, x in
                view.offset(x: x)
            } keyframes: { _ in
                let quarter = Motion.Period.shake / 4
                KeyframeTrack {
                    CubicKeyframe(-Self.swing, duration: quarter)
                    CubicKeyframe(Self.swing, duration: quarter * 2)
                    CubicKeyframe(0, duration: quarter)
                    CubicKeyframe(-Self.swing, duration: quarter)
                    CubicKeyframe(Self.swing, duration: quarter * 2)
                    CubicKeyframe(0, duration: quarter)
                }
            }
        }
    }
}

extension View {
    func shake<Trigger: Equatable & Sendable>(trigger: Trigger) -> some View {
        modifier(Shake(trigger: trigger))
    }
}

#Preview("Shake") {
    struct Demo: View {
        @State private var shakes = 0
        var body: some View {
            VStack(spacing: Space.s4) {
                Text("+02:14")
                    .font(Typography.timerHero)
                    .foregroundStyle(Palette.dangerText)
                    .shake(trigger: shakes)
                Button("Time's up") { shakes += 1 }
            }
            .padding(Space.s8 * 2)
            .background(Palette.bg)
        }
    }
    return Demo()
}
