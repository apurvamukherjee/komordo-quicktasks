import SwiftUI

/// The rotating conic border on the live task (DESIGN_HANDOFF §4.2). It's drawn as a filled shape
/// behind content inset by the beam width, like the canvas's padded `.k-beam`, so its glow is
/// an outer glow only. The content must be opaque.
struct BeamBorder: View {
    var tone: TimerTone
    var radius: CGFloat = Radius.hero

    static let width: CGFloat = 1.5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var moving: Bool { tone.isMoving && !reduceMotion }

    var body: some View {
        TimelineView(.animation(paused: !moving)) { context in
            let turns = moving ? context.date.timeIntervalSinceReferenceDate / Motion.Period.beam : 0
            let angle = Angle.degrees(turns.truncatingRemainder(dividingBy: 1) * 360)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(gradient(from: angle))
        }
        .modifier(BeamGlow(color: tone.glow, breathes: moving))
    }

    // Stops at 0°, 60°, 120° and 190° (the canvas's conic-gradient). SwiftUI measures from 3 o'clock
    // and CSS from 12, hence the −90°.
    private func gradient(from angle: Angle) -> AngularGradient {
        let (base, lead, tail) = tone.beam
        let start = angle - .degrees(90)
        return AngularGradient(
            stops: [
                .init(color: base, location: 0),
                .init(color: lead, location: 60.0 / 360),
                .init(color: tail, location: 120.0 / 360),
                .init(color: base, location: 190.0 / 360),
                .init(color: base, location: 1),
            ],
            center: .center,
            startAngle: start,
            endAngle: start + .degrees(360)
        )
    }
}

/// The glow breathes between the canvas's 36 pt and 66 pt blur over 3.2 s.
private struct BeamGlow: ViewModifier {
    var color: Color?
    var breathes: Bool

    private enum Glow {
        static let restOpacity = 0.3
        static let peakOpacity = 0.65
        static let restRadius: CGFloat = 18
        static let peakRadius: CGFloat = 32
    }

    func body(content: Content) -> some View {
        if let color {
            if breathes {
                content.phaseAnimator([0.0, 1.0]) { view, phase in
                    view.shadow(
                        color: color.opacity(Glow.restOpacity + (Glow.peakOpacity - Glow.restOpacity) * phase),
                        radius: Glow.restRadius + (Glow.peakRadius - Glow.restRadius) * phase
                    )
                } animation: { _ in
                    .easeInOut(duration: Motion.Period.breathe / 2)
                }
            } else {
                content.shadow(color: color.opacity(Glow.restOpacity), radius: Glow.restRadius)
            }
        } else {
            content
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
