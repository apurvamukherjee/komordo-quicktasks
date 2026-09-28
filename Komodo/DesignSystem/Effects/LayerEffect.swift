import AppKit
import SwiftUI

/// Hosts an effect drawn with Core Animation. The continuous effects (beam, halo, aurora, sheen, ping) loop
/// as layer animations, which the window server runs on its own, so a looping effect costs the app nothing per
/// frame. Drawn with `TimelineView` they re-ran the view graph and the Board's layout 60 times a second.
struct LayerEffect<Effect: EffectLayerView>: NSViewRepresentable {
    var update: (Effect) -> Void

    func makeNSView(context: Context) -> Effect { Effect(frame: .zero) }

    func updateNSView(_ view: Effect, context: Context) { update(view) }
}

/// Base for the effect views: y-down like SwiftUI, never hit-tested, with sublayers kept at the screen's scale.
class EffectLayerView: NSView {
    override required init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerUsesCoreImageFilters = true
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1
        func apply(_ layer: CALayer) {
            layer.contentsScale = scale
            if layer.shouldRasterize { layer.rasterizationScale = scale }
            layer.sublayers?.forEach(apply)
        }
        layer?.sublayers?.forEach(apply)
    }

    /// Palette colors resolved in this view's appearance, since `cgColor` would otherwise use whatever
    /// appearance happens to be current.
    func cgColor(_ color: Color) -> CGColor {
        var resolved = NSColor(color).cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance { resolved = NSColor(color).cgColor }
        return resolved
    }

    /// Runs layer changes without Core Animation's implicit 0.25 s animations.
    func withoutActions(_ changes: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        changes()
        CATransaction.commit()
    }
}

extension CAMediaTimingFunction {
    /// The house curve, `cubic-bezier(0.2, 0.8, 0.2, 1)`, as `Motion.base` and `Motion.slow` use it.
    static var house: CAMediaTimingFunction { CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1) }
}

extension CAAnimation {
    /// Loops forever in step with the wall clock, so every copy of an effect moves together and a rebuilt
    /// layer picks up where the old one was. `period` is one full cycle, both legs if it autoreverses.
    func loopingForever(period: TimeInterval) -> Self {
        repeatCount = .infinity
        timeOffset = Date.now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        return self
    }
}
