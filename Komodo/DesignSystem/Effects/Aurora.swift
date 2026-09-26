import SwiftUI

/// Two soft blobs, teal and lime, drifting ±6% and swelling to 1.08 over 9 s behind the Today stage
/// (DESIGN_SYSTEM §5.1). Still under Reduce Motion.
struct Aurora: View {
    private static let period: TimeInterval = 9

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let phase = reduceMotion ? 0.5 : Self.phase(at: context.date)
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                ZStack {
                    EllipticalGradient(
                        colors: [Palette.teal.opacity(0.22), .clear], startRadiusFraction: 0, endRadiusFraction: 0.7
                    )
                    .frame(width: width, height: height * 1.2)
                    .position(x: width * 0.3, y: height * 0.5)
                    EllipticalGradient(
                        colors: [Palette.lime.opacity(0.16), .clear], startRadiusFraction: 0, endRadiusFraction: 0.7
                    )
                    .frame(width: width * 0.9, height: height * 1.1)
                    .position(x: width * 0.72, y: height * 0.4)
                }
                .offset(x: width * (-0.06 + 0.12 * phase))
                .scaleEffect(1 + 0.08 * phase)
            }
            .blur(radius: 10)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 0 → 1 → 0 with easing at both ends, like the canvas's `alternate ease-in-out` loop.
    private static func phase(at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate / (period * 2)
        return (1 - cos(2 * .pi * t)) / 2
    }
}

#Preview("Aurora") {
    Aurora()
        .frame(width: 560, height: 380)
        .background(Palette.panel)
}
