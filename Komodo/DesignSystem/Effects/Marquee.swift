import AppKit
import SwiftUI

/// `.ft-mq` (FloatingTimer.png): a title wider than its cap scrolls to its end and back, holding at each end,
/// behind a fade at both edges, and pauses while hovered. Short titles and Reduce Motion show plain text.
struct MarqueeText: View {
    var text: String
    var width: CGFloat
    var font: NSFont
    var color: Color
    /// Off truncates instead, as Settings' Scrolling title allows.
    var scrolls = true
    var isPaused = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var textWidth: CGFloat { (text as NSString).size(withAttributes: [.font: font]).width }

    var body: some View {
        if !scrolls || reduceMotion || textWidth <= width {
            Text(text)
                .font(Font(font))
                .foregroundStyle(color)
                .lineLimit(1)
                .frame(maxWidth: width, alignment: .leading)
        } else {
            LayerEffect<MarqueeLayerView> { $0.show(text, font: font, color: $0.cgColor(color), isPaused: isPaused) }
                .frame(width: width, height: ceil(font.ascender - font.descender + font.leading))
                .accessibilityElement()
                .accessibilityLabel(text)
        }
    }
}

final class MarqueeLayerView: EffectLayerView {
    /// One leg, end to end; the canvas's 7 s with 16% held at each end.
    private static let leg: TimeInterval = 7
    private static let inset: CGFloat = 4

    private let textLayer = CATextLayer()
    private let fade = CAGradientLayer()
    private var shown: NSAttributedString?
    private var isPaused = false

    required init(frame: NSRect) {
        super.init(frame: frame)
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        layer?.addSublayer(textLayer)
        fade.startPoint = CGPoint(x: 0, y: 0.5)
        fade.endPoint = CGPoint(x: 1, y: 0.5)
        fade.colors = [NSColor.clear.cgColor, NSColor.black.cgColor, NSColor.black.cgColor, NSColor.clear.cgColor]
        fade.locations = [0, 0.07, 0.88, 1]
        layer?.mask = fade
    }

    required init?(coder: NSCoder) { nil }

    func show(_ text: String, font: NSFont, color: CGColor, isPaused: Bool) {
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        if string != shown {
            shown = string
            textLayer.string = string
            needsLayout = true
        }
        if isPaused != self.isPaused {
            self.isPaused = isPaused
            isPaused ? pause() : resume()
        }
    }

    override func layout() {
        super.layout()
        guard let shown else { return }
        let size = shown.size()
        withoutActions {
            fade.frame = bounds
            textLayer.frame = CGRect(
                x: Self.inset, y: (bounds.height - size.height) / 2, width: ceil(size.width), height: size.height)
        }
        scroll(by: size.width + 2 * Self.inset - bounds.width)
    }

    private func scroll(by distance: CGFloat) {
        textLayer.removeAnimation(forKey: "marquee")
        guard distance > 0 else { return }
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [0, 0, -distance, -distance]
        animation.keyTimes = [0, 0.16, 0.84, 1]
        animation.timingFunctions = [.init(name: .linear), .init(name: .easeInEaseOut), .init(name: .linear)]
        animation.duration = Self.leg
        animation.autoreverses = true
        textLayer.add(animation.loopingForever(period: 2 * Self.leg), forKey: "marquee")
        if isPaused { pause() }
    }

    private func pause() {
        textLayer.timeOffset = textLayer.convertTime(CACurrentMediaTime(), from: nil)
        textLayer.speed = 0
    }

    private func resume() {
        let pausedAt = textLayer.timeOffset
        textLayer.speed = 1
        textLayer.timeOffset = 0
        textLayer.beginTime = 0
        textLayer.beginTime = textLayer.convertTime(CACurrentMediaTime(), from: nil) - pausedAt
    }
}

#Preview("Marquee") {
    VStack(alignment: .leading, spacing: Space.s3) {
        MarqueeText(
            text: "Design review prep with Apurva and the launch crew", width: 200,
            font: .systemFont(ofSize: 13, weight: .semibold), color: Palette.textBody)
        MarqueeText(
            text: "Short title", width: 200, font: .systemFont(ofSize: 13, weight: .semibold),
            color: Palette.textBody)
    }
    .padding(Space.s6)
    .background(Palette.bg)
}
