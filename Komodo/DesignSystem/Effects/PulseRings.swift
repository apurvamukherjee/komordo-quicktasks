import SwiftUI

/// Two rings that swell out of a button and fade, half a cycle apart (Onboarding ⑦, `ob-ring`): the tip pointing
/// at Start. Off under Reduce Motion.
private struct PulseRings: ViewModifier {
    var color: Color
    var cornerRadius: CGFloat
    var isOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if isOn && !reduceMotion {
                LayerEffect<PulseRingsLayerView> { $0.configure(color: color, cornerRadius: cornerRadius) }
                    .padding(-3)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

private final class PulseRingsLayerView: EffectLayerView {
    private let rings = [CALayer(), CALayer()]

    required init(frame: NSRect) {
        super.init(frame: frame)
        for (index, ring) in rings.enumerated() {
            ring.borderWidth = 2
            ring.opacity = 0
            layer?.addSublayer(ring)
            // Wider than it grows tall in points, so the ring keeps an even gap around a wide button.
            let scale = CABasicAnimation(keyPath: "transform")
            scale.fromValue = NSValue(caTransform3D: CATransform3DIdentity)
            scale.toValue = NSValue(caTransform3D: CATransform3DMakeScale(1.35, 1.6, 1))
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.9
            fade.toValue = 0
            let ping = CAAnimationGroup()
            ping.animations = [scale, fade]
            ping.duration = Motion.Period.ping
            ping.timingFunction = .house
            let looping = ping.loopingForever(period: Motion.Period.ping)
            looping.timeOffset += Motion.Period.ping / 2 * Double(index)
            ring.add(looping, forKey: "ring")
        }
    }

    required init?(coder: NSCoder) { nil }

    func configure(color: Color, cornerRadius: CGFloat) {
        withoutActions {
            for ring in rings {
                ring.borderColor = cgColor(color)
                ring.cornerRadius = cornerRadius
            }
        }
    }

    override func layout() {
        super.layout()
        withoutActions { for ring in rings { ring.frame = bounds } }
    }
}

extension View {
    /// Rings around a control that the person should press next.
    func pulseRings(_ color: Color, cornerRadius: CGFloat, isOn: Bool = true) -> some View {
        modifier(PulseRings(color: color, cornerRadius: cornerRadius, isOn: isOn))
    }
}

#Preview("Pulse rings") {
    Button("Start", systemImage: "play.fill") {}
        .buttonStyle(.komodo(.primary))
        .pulseRings(Palette.lime, cornerRadius: 13)
        .padding(Space.s8 * 2)
        .background(Palette.bg)
}
