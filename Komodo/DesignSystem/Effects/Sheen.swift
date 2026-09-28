import SwiftUI

/// The diagonal light that sweeps across primary buttons every 3.6 s (DESIGN_SYSTEM §5).
/// Idle for the first 62% of each loop, then crosses on the house curve.
private struct Sheen: ViewModifier {
    var cornerRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                LayerEffect<SheenLayerView> { $0.configure(cornerRadius: cornerRadius) }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

private final class SheenLayerView: EffectLayerView {
    private static let idleShare = 0.62
    /// How far past each edge the light starts and ends, as a fraction of the width.
    private static let travel: CGFloat = 1.3
    private static let sweepKey = "sweep"

    private let clip = CALayer()
    private let light = CAGradientLayer()
    private var animatedWidth: CGFloat = 0

    required init(frame: NSRect) {
        super.init(frame: frame)
        light.colors = [NSColor.clear.cgColor, NSColor.white.withAlphaComponent(0.55).cgColor, NSColor.clear.cgColor]
        light.locations = [0.3, 0.5, 0.7]
        // CSS 110°: mostly left to right, tipping downward.
        light.startPoint = CGPoint(x: 0.03, y: 0.33)
        light.endPoint = CGPoint(x: 0.97, y: 0.67)
        clip.masksToBounds = true
        clip.cornerCurve = .continuous
        clip.addSublayer(light)
        layer?.addSublayer(clip)
    }

    required init?(coder: NSCoder) { nil }

    func configure(cornerRadius: CGFloat) {
        withoutActions { clip.cornerRadius = cornerRadius }
    }

    override func layout() {
        super.layout()
        let width = bounds.width
        withoutActions {
            clip.frame = bounds
            light.bounds = bounds
            light.position = CGPoint(x: bounds.midX - width * Self.travel, y: bounds.midY)
        }
        guard width != animatedWidth else { return }
        // The sweep is in points, so it's rebuilt when the width changes.
        animatedWidth = width
        let offstage = bounds.midX - width * Self.travel
        let sweep = CAKeyframeAnimation(keyPath: "position.x")
        sweep.values = [offstage, offstage, bounds.midX + width * Self.travel]
        sweep.keyTimes = [0, NSNumber(value: Self.idleShare), 1]
        sweep.timingFunctions = [CAMediaTimingFunction(name: .linear), .house]
        sweep.duration = Motion.Period.sheen
        light.add(sweep.loopingForever(period: Motion.Period.sheen), forKey: Self.sweepKey)
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
