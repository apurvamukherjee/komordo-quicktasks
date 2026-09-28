import SwiftUI

/// A ring that swells out of a status dot and fades, on a 1.6 s loop (DESIGN_SYSTEM §5: scanning,
/// the live dot). Off under Reduce Motion.
private struct Ping: ViewModifier {
    var color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                LayerEffect<PingLayerView> { $0.configure(color: color) }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

private final class PingLayerView: EffectLayerView {
    private static let startOpacity: Float = 0.7
    private static let endScale = 2.8
    private static let pingKey = "ping"

    private let ring = CALayer()

    required init(frame: NSRect) {
        super.init(frame: frame)
        ring.opacity = 0
        layer?.addSublayer(ring)

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1
        scale.toValue = Self.endScale
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = Self.startOpacity
        fade.toValue = 0
        let ping = CAAnimationGroup()
        ping.animations = [scale, fade]
        ping.duration = Motion.Period.ping
        ping.timingFunction = .house
        ring.add(ping.loopingForever(period: Motion.Period.ping), forKey: Self.pingKey)
    }

    required init?(coder: NSCoder) { nil }

    func configure(color: Color) {
        withoutActions { ring.backgroundColor = cgColor(color) }
    }

    override func layout() {
        super.layout()
        withoutActions {
            ring.frame = bounds
            ring.cornerRadius = min(bounds.width, bounds.height) / 2
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
