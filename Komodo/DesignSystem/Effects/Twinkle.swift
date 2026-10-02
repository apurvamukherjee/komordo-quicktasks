import SwiftUI

/// Four 4 pt sparks that swell and fade in turn around a celebration (FocusStates ⑦, `fs-twinkle`). Off under
/// Reduce Motion.
private struct Twinkle: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if !reduceMotion {
                LayerEffect<TwinkleLayerView> { $0.configure() }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }
}

private final class TwinkleLayerView: EffectLayerView {
    /// Where the canvas puts each spark on its 316 pt card: x as a share of the width, y from the top.
    private static let spots: [(x: CGFloat, y: CGFloat, color: Color)] = [
        (28 / 316, 24, Palette.lime), (270 / 316, 36, Palette.amber), (220 / 316, 16, Palette.pink),
        (290 / 316, 90, Palette.teal),
    ]
    private static let side: CGFloat = 4

    private let sparks = spots.map { _ in CALayer() }

    required init(frame: NSRect) {
        super.init(frame: frame)
        for (index, spark) in sparks.enumerated() {
            spark.cornerRadius = Self.side / 2
            spark.opacity = 0.15
            layer?.addSublayer(spark)
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.15
            fade.toValue = 1
            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.6
            scale.toValue = 1.3
            let twinkle = CAAnimationGroup()
            twinkle.animations = [fade, scale]
            twinkle.duration = Motion.Period.twinkle / 2
            twinkle.autoreverses = true
            twinkle.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            let looping = twinkle.loopingForever(period: Motion.Period.twinkle)
            // Each spark peaks a quarter cycle after the one before, as the canvas's animation delays do.
            looping.timeOffset += Motion.Period.twinkle * Double(index) / Double(Self.spots.count)
            spark.add(looping, forKey: "twinkle")
        }
    }

    required init?(coder: NSCoder) { nil }

    func configure() {
        withoutActions {
            for (spark, spot) in zip(sparks, Self.spots) { spark.backgroundColor = cgColor(spot.color) }
        }
    }

    override func layout() {
        super.layout()
        withoutActions {
            for (spark, spot) in zip(sparks, Self.spots) {
                spark.frame = CGRect(x: bounds.width * spot.x, y: spot.y, width: Self.side, height: Self.side)
            }
        }
    }
}

extension View {
    func twinkle() -> some View {
        modifier(Twinkle())
    }
}

#Preview("Twinkle") {
    RoundedRectangle(cornerRadius: 22.5, style: .continuous)
        .fill(Palette.panel)
        .frame(width: 316, height: 160)
        .twinkle()
        .padding(Space.s8)
        .background(Palette.bg)
}
