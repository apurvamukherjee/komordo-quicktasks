import AppKit
import SwiftUI

/// SwiftUI content in a hosting view of its own, so Core Animation can roll or fade its layer. A SwiftUI animation
/// here would re-run the whole window's layout every frame: the timer's rolling digits and beating colon kept the
/// Board near 50% CPU that way. The content gets the surrounding environment (font, tracking, color), and looks
/// are applied by `update`.
struct HostedLayer<Content: View>: NSViewRepresentable {
    /// A window onto content larger than it, such as a digit cell over its 0–9 strip; nil takes the content's size.
    var size: CGSize?
    var content: Content
    var update: (HostedLayerView) -> Void

    init(
        size: CGSize? = nil, @ViewBuilder content: () -> Content, update: @escaping (HostedLayerView) -> Void
    ) {
        self.size = size
        self.content = content()
        self.update = update
    }

    func makeNSView(context: Context) -> HostedLayerView { HostedLayerView() }

    func updateNSView(_ view: HostedLayerView, context: Context) {
        view.hosting.rootView = AnyView(content.environment(\.self, context.environment))
        update(view)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: HostedLayerView, context: Context) -> CGSize? {
        size ?? nsView.hosting.fittingSize
    }
}

/// The host: never hit-tested, top-down like SwiftUI, with the content pinned to its top-left at its own size, so
/// a strip taller than the view can slide under the clip.
final class HostedLayerView: NSView {
    let hosting = NSHostingView(rootView: AnyView(EmptyView()))
    private var shownOffset: CGFloat?
    private var loopName: String?

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        // macOS 14 stopped clipping subviews by default, and a digit strip must stay inside its cell.
        clipsToBounds = true
        addSubview(hosting)
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        hosting.frame = CGRect(origin: .zero, size: hosting.fittingSize)
    }
}

extension HostedLayerView {
    /// Slides the content up by `offset` inside the view's clip, on a spring like `Motion.spring` when animated.
    func slide(to offset: CGFloat, animated: Bool) {
        guard let layer, offset != shownOffset else { return }
        let target = CATransform3DMakeTranslation(0, -offset, 0)
        if animated, shownOffset != nil {
            // Motion.spring: response 0.4, damping fraction 0.62.
            let spring = CASpringAnimation(perceptualDuration: 0.4, bounce: 0.38)
            spring.keyPath = "sublayerTransform"
            spring.fromValue = NSValue(
                caTransform3D: layer.presentation()?.sublayerTransform ?? layer.sublayerTransform)
            spring.toValue = NSValue(caTransform3D: target)
            spring.duration = spring.settlingDuration
            layer.add(spring, forKey: "slide")
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.sublayerTransform = target
        CATransaction.commit()
        shownOffset = offset
    }

    /// Runs `make`'s looping animation under `name`, replacing another; nil stops it at `opacity`.
    func loop(_ name: String?, opacity: Double, make: () -> CAAnimation) {
        alphaValue = opacity
        guard name != loopName, let layer else { return }
        layer.removeAnimation(forKey: "loop")
        loopName = name
        if name != nil { layer.add(make(), forKey: "loop") }
    }
}
