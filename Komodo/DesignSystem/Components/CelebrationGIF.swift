import AppKit
import SwiftUI

/// The celebration's fun GIF (FEATURES §4.13): one of the bundled Animated Noto Emoji (CC BY 4.0), so it works
/// offline. SwiftUI's `Image` draws only a GIF's first frame, so an `NSImageView` plays it; under Reduce Motion
/// it stays on that still frame.
struct CelebrationGIF: View {
    var url: URL
    var isStill: Bool

    /// Every bundled GIF, picked from at random on each Done.
    static let bundled: [URL] = (Bundle.main.urls(forResourcesWithExtension: "gif", subdirectory: nil) ?? [])
        .filter { $0.lastPathComponent.hasPrefix("celebration-") }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        AnimatedImage(url: url, animates: !isStill)
            // The GIFs are 200 px, so 100 pt keeps them sharp on a Retina screen.
            .frame(width: 100, height: 100)
            .frame(width: 240, height: 180)
            .background {
                ZStack {
                    Palette.card
                    RadialGradient(
                        colors: [Palette.lime.opacity(0.16), .clear], center: .center, startRadius: 0, endRadius: 110)
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.border))
            .accessibilityHidden(true)
    }
}

private struct AnimatedImage: NSViewRepresentable {
    var url: URL
    var animates: Bool

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateNSView(_ view: NSImageView, context: Context) {
        if view.image == nil || context.coordinator.url != url {
            view.image = NSImage(contentsOf: url)
            context.coordinator.url = url
        }
        view.animates = animates
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var url: URL?
    }
}

#Preview("Celebration GIF") {
    HStack(spacing: Space.s4) {
        if let url = CelebrationGIF.bundled.first {
            CelebrationGIF(url: url, isStill: false)
            CelebrationGIF(url: url, isStill: true)
        }
    }
    .padding(Space.s8)
    .background(Palette.bg)
}
