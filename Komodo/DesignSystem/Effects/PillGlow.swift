import SwiftUI

/// The floating timer's outer glow (DESIGN_SYSTEM §10.5): a soft lime glow that breathes while the timer runs,
/// and a steady red or green one at Time's Up and on a break. A shadow under a plain rounded layer, so only the
/// shadow animates; it holds still under Reduce Motion.
struct PillGlow: View {
    var color: Color?
    var breathes: Bool
    var radius: CGFloat = Radius.tile

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LayerEffect<PillGlowLayerView> {
            $0.configure(color: color, radius: radius, breathes: breathes && !reduceMotion)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private final class PillGlowLayerView: EffectLayerView {
    private enum Glow {
        static let steadyOpacity: Float = 0.7
        static let peakOpacity: Float = 0.42
        static let blur: CGFloat = 15
        static let key = "breathe"
    }

    private let glow = CALayer()
    private var radius: CGFloat = 0

    required init(frame: NSRect) {
        super.init(frame: frame)
        glow.shadowOffset = .zero
        glow.shadowRadius = Glow.blur
        glow.cornerCurve = .continuous
        layer?.addSublayer(glow)
    }

    required init?(coder: NSCoder) { nil }

    func configure(color: Color?, radius: CGFloat, breathes: Bool) {
        withoutActions {
            glow.shadowColor = color.map(cgColor)
            glow.shadowOpacity = color == nil || breathes ? 0 : Glow.steadyOpacity
        }
        if radius != self.radius {
            self.radius = radius
            needsLayout = true
        }
        if breathes, color != nil {
            guard glow.animation(forKey: Glow.key) == nil else { return }
            let breathe = CABasicAnimation(keyPath: "shadowOpacity")
            breathe.fromValue = 0
            breathe.toValue = Glow.peakOpacity
            breathe.duration = Motion.Period.breathe / 2
            breathe.autoreverses = true
            breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            glow.add(breathe.loopingForever(period: Motion.Period.breathe), forKey: Glow.key)
        } else {
            glow.removeAnimation(forKey: Glow.key)
        }
    }

    override func layout() {
        super.layout()
        withoutActions {
            glow.frame = bounds
            // The shadow is all that shows; the path keeps it from drawing the layer itself.
            glow.shadowPath = CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)
        }
    }
}

/// ⌘⇧P's locator (FloatingTimer.dc.html): three teal rings swell off the pill in 0.9 s. Each new `trigger`
/// plays it once; under Reduce Motion the ring flashes in place instead of swelling.
struct LocatorRipple: View {
    var trigger: Int
    var radius: CGFloat = Radius.tile

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LayerEffect<LocatorRippleLayerView> {
            $0.configure(trigger: trigger, color: Palette.teal, radius: radius, swells: !reduceMotion)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private final class LocatorRippleLayerView: EffectLayerView {
    private static let pulse: TimeInterval = 0.3
    private static let count: Float = 3

    private let ring = CALayer()
    private var trigger: Int?
    private var radius: CGFloat = 0

    required init(frame: NSRect) {
        super.init(frame: frame)
        ring.borderWidth = 2
        ring.cornerCurve = .continuous
        ring.opacity = 0
        ring.shadowOffset = .zero
        ring.shadowRadius = 9
        ring.shadowOpacity = 0.7
        layer?.addSublayer(ring)
    }

    required init?(coder: NSCoder) { nil }

    func configure(trigger: Int, color: Color, radius: CGFloat, swells: Bool) {
        withoutActions {
            ring.borderColor = cgColor(color)
            ring.shadowColor = cgColor(color)
            ring.cornerRadius = radius
        }
        self.radius = radius
        // The first value is whatever the store held at launch; only later changes play.
        defer { self.trigger = trigger }
        guard let previous = self.trigger, previous != trigger else { return }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.95
        fade.toValue = 0
        let ripple = CAAnimationGroup()
        if swells {
            let scale = CABasicAnimation(keyPath: "transform")
            scale.fromValue = CATransform3DIdentity
            scale.toValue = CATransform3DMakeScale(1.14, 1.9, 1)
            ripple.animations = [fade, scale]
        } else {
            ripple.animations = [fade]
        }
        ripple.duration = Self.pulse
        ripple.repeatCount = Self.count
        ripple.timingFunction = .house
        ring.add(ripple, forKey: "locate")
    }

    override func layout() {
        super.layout()
        withoutActions {
            ring.frame = bounds
            ring.cornerRadius = radius
        }
    }
}

#Preview("Pill glow and locator") {
    struct Demo: View {
        @State private var pings = 0

        var body: some View {
            VStack(spacing: Space.s8) {
                ForEach([Palette.lime, Palette.danger, Palette.green], id: \.self) { color in
                    RoundedRectangle(cornerRadius: Radius.tile)
                        .fill(Palette.raised)
                        .frame(width: 240, height: 40)
                        .background(PillGlow(color: color, breathes: color == Palette.lime))
                }
                RoundedRectangle(cornerRadius: Radius.tile)
                    .fill(Palette.raised)
                    .frame(width: 240, height: 40)
                    .overlay(LocatorRipple(trigger: pings))
                    .onTapGesture { pings += 1 }
            }
            .padding(Space.s8 * 2)
            .background(Palette.bg)
        }
    }
    return Demo()
}
