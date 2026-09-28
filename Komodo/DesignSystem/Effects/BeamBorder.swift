import SwiftUI

/// The rotating conic border on the live task (DESIGN_HANDOFF §4.2). It's drawn as a filled shape
/// behind content inset by the beam width, like the canvas's padded `.k-beam`, so its glow is
/// an outer glow only. The content must be opaque.
struct BeamBorder: View {
    var tone: TimerTone
    var radius: CGFloat = Radius.hero

    static let width: CGFloat = 1.5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let moving = tone.isMoving && !reduceMotion
        LayerEffect<BeamLayerView> { $0.configure(tone: tone, radius: radius, moving: moving) }
            .accessibilityHidden(true)
    }
}

/// The glow breathes between the canvas's 36 pt and 66 pt blur over 3.2 s. It's the shadow of a plain rounded
/// layer under the beam, so only the shadow animates.
private final class BeamLayerView: EffectLayerView {
    private enum Glow {
        static let restOpacity: Float = 0.3
        static let peakOpacity: Float = 0.65
        static let restRadius: CGFloat = 18
        static let peakRadius: CGFloat = 32
    }

    private enum Key {
        static let spin = "spin"
        static let breathe = "breathe"
    }

    private let glow = CALayer()
    private let beam = CALayer()
    private let gradient = CAGradientLayer()
    private var radius: CGFloat = 0

    required init(frame: NSRect) {
        super.init(frame: frame)
        glow.shadowOffset = .zero
        glow.cornerCurve = .continuous
        beam.cornerCurve = .continuous
        beam.masksToBounds = true
        gradient.type = .conic
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        // Straight up, where the canvas's CSS conic-gradient starts.
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        // Stops at 0°, 60°, 120° and 190°, as on the canvas.
        gradient.locations = [0, 60.0 / 360, 120.0 / 360, 190.0 / 360, 1].map { NSNumber(value: $0) }
        beam.addSublayer(gradient)
        layer?.addSublayer(glow)
        layer?.addSublayer(beam)
    }

    required init?(coder: NSCoder) { nil }

    func configure(tone: TimerTone, radius: CGFloat, moving: Bool) {
        let (base, lead, tail) = tone.beam
        withoutActions {
            gradient.colors = [base, lead, tail, base, base].map(cgColor)
            glow.backgroundColor = cgColor(base)
            glow.shadowColor = tone.glow.map(cgColor)
            glow.shadowOpacity = tone.glow == nil ? 0 : Glow.restOpacity
            glow.shadowRadius = Glow.restRadius
            glow.cornerRadius = radius
            beam.cornerRadius = radius
        }
        if radius != self.radius {
            self.radius = radius
            needsLayout = true
        }

        if moving {
            if gradient.animation(forKey: Key.spin) == nil {
                let spin = CABasicAnimation(keyPath: "transform.rotation.z")
                spin.fromValue = 0
                spin.toValue = 2 * Double.pi
                spin.duration = Motion.Period.beam
                gradient.add(spin.loopingForever(period: Motion.Period.beam), forKey: Key.spin)
            }
        } else {
            gradient.removeAnimation(forKey: Key.spin)
        }

        if moving && tone.glow != nil {
            if glow.animation(forKey: Key.breathe) == nil {
                let opacity = CABasicAnimation(keyPath: "shadowOpacity")
                opacity.fromValue = Glow.restOpacity
                opacity.toValue = Glow.peakOpacity
                let blur = CABasicAnimation(keyPath: "shadowRadius")
                blur.fromValue = Glow.restRadius
                blur.toValue = Glow.peakRadius
                let breathe = CAAnimationGroup()
                breathe.animations = [opacity, blur]
                breathe.duration = Motion.Period.breathe / 2
                breathe.autoreverses = true
                breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                glow.add(breathe.loopingForever(period: Motion.Period.breathe), forKey: Key.breathe)
            }
        } else {
            glow.removeAnimation(forKey: Key.breathe)
        }
    }

    override func layout() {
        super.layout()
        withoutActions {
            glow.frame = bounds
            glow.shadowPath = CGPath(
                roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)
            beam.frame = bounds
            // A square as wide as the diagonal, so the spinning gradient always covers the corners.
            let side = hypot(bounds.width, bounds.height)
            gradient.bounds = CGRect(x: 0, y: 0, width: side, height: side)
            gradient.position = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }
}

extension View {
    /// Wraps the view in a border beam. The view keeps its own background, clipped to the inner radius.
    func beamBorder(_ tone: TimerTone, radius: CGFloat = Radius.hero) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius - BeamBorder.width, style: .continuous))
            .padding(BeamBorder.width)
            .background(BeamBorder(tone: tone, radius: radius))
    }
}

#Preview("BeamBorder · every tone") {
    VStack(spacing: Space.s6) {
        ForEach(TimerTone.allCases, id: \.self) { tone in
            Text(String(describing: tone))
                .font(Typography.body)
                .foregroundStyle(Palette.textTertiary)
                .frame(width: 320, height: 90)
                .background(Palette.panel)
                .beamBorder(tone)
        }
    }
    .padding(Space.s8 * 2)
    .background(Palette.bg)
}
