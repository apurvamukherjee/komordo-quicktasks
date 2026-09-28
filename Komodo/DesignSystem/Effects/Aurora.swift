import CoreImage
import SwiftUI

/// Two soft blobs, teal and lime, drifting ±6% and swelling to 1.08 over 9 s behind the Today stage
/// (DESIGN_SYSTEM §5.1). Still under Reduce Motion.
struct Aurora: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LayerEffect<AuroraLayerView> { $0.configure(moving: !reduceMotion) }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The blobs are blurred once and rasterized; only the container's transform animates.
private final class AuroraLayerView: EffectLayerView {
    private static let period: TimeInterval = 9
    private static let drift: CGFloat = 0.06
    private static let swell: CGFloat = 1.08
    private static let driftKey = "drift"

    private let container = CALayer()
    private let teal = CAGradientLayer()
    private let lime = CAGradientLayer()
    private var moving = false
    private var animatedWidth: CGFloat = 0

    required init(frame: NSRect) {
        super.init(frame: frame)
        for blob in [teal, lime] {
            blob.type = .radial
            blob.startPoint = CGPoint(x: 0.5, y: 0.5)
            // SwiftUI's `endRadiusFraction: 0.7` is 70% of the frame's size out from the centre.
            blob.endPoint = CGPoint(x: 1.2, y: 1.2)
            container.addSublayer(blob)
        }
        container.filters = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: 10]).map { [$0] }
        container.shouldRasterize = true
        layer?.addSublayer(container)
    }

    required init?(coder: NSCoder) { nil }

    func configure(moving: Bool) {
        withoutActions {
            teal.colors = [Palette.teal.opacity(0.22), .clear].map(cgColor)
            lime.colors = [Palette.lime.opacity(0.16), .clear].map(cgColor)
        }
        if moving != self.moving {
            self.moving = moving
            animatedWidth = 0
            needsLayout = true
        }
    }

    override func layout() {
        super.layout()
        let width = bounds.width
        let height = bounds.height
        withoutActions {
            container.frame = bounds
            teal.bounds = CGRect(x: 0, y: 0, width: width, height: height * 1.2)
            teal.position = CGPoint(x: width * 0.3, y: height * 0.5)
            lime.bounds = CGRect(x: 0, y: 0, width: width * 0.9, height: height * 1.1)
            lime.position = CGPoint(x: width * 0.72, y: height * 0.4)
            // Reduce Motion holds the midpoint of the drift.
            container.transform = moving ? CATransform3DIdentity : CATransform3DMakeScale(1.04, 1.04, 1)
        }
        guard moving, width != animatedWidth else {
            if !moving { container.removeAnimation(forKey: Self.driftKey) }
            return
        }
        // The drift is in points, so it's rebuilt when the width changes.
        animatedWidth = width
        let shift = CABasicAnimation(keyPath: "transform.translation.x")
        shift.fromValue = -width * Self.drift
        shift.toValue = width * Self.drift
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1
        scale.toValue = Self.swell
        let drift = CAAnimationGroup()
        drift.animations = [shift, scale]
        drift.duration = Self.period
        drift.autoreverses = true
        drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        container.add(drift.loopingForever(period: Self.period * 2), forKey: Self.driftKey)
    }
}

#Preview("Aurora") {
    Aurora()
        .frame(width: 560, height: 380)
        .background(Palette.panel)
}
