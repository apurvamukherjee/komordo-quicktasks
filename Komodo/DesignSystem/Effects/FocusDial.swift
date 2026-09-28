import CoreImage
import KomodoCore
import SwiftUI

/// Geometry of one dial size, taken from the canvas rather than scaled, because the artboards
/// tune tick lengths and halo blur per size.
struct FocusDialMetrics: Sendable {
    var size: CGFloat
    var ringRadius: CGFloat
    var ringWidth: CGFloat
    var majorTick: CGFloat
    var minorTick: CGFloat
    var tickWidth: CGFloat = 2
    var comet: CGFloat
    var haloInset: CGFloat
    var haloBlur: CGFloat
    var haloOpacity = 0.55

    /// The live card on the Board (Main.dc.html).
    static let board = FocusDialMetrics(
        size: 120, ringRadius: 42, ringWidth: 7, majorTick: 9, minorTick: 6, comet: 13, haloInset: 18, haloBlur: 14
    )
    /// The inspector's live header (Inspector.dc.html): the ring alone, no ticks, comet or halo.
    static let inspector = FocusDialMetrics(
        size: 46, ringRadius: 18, ringWidth: 5, majorTick: 0, minorTick: 0, comet: 0, haloInset: 0, haloBlur: 0,
        haloOpacity: 0
    )
    /// The Foundations motion demo.
    static let showcase = FocusDialMetrics(
        size: 150, ringRadius: 54, ringWidth: 8, majorTick: 10, minorTick: 6, comet: 14, haloInset: 14, haloBlur: 12
    )
}

// Outside `FocusDial` because generic types can't hold static stored properties.
private enum Sweep {
    static let trail = 14
    static let fadeSteps = 15.0
    static let restMajor = 0.2
    static let restMinor = 0.09
    static let pausedLit = 0.5
    static let headGlow = 0.9
    static let headGlowRadius: CGFloat = 5
    static let cometGlowRadius: CGFloat = 9
    static let cometGlow = 0.95
    static let pausedCometGlow = 0.4
}

/// The live timer's dial (DESIGN_HANDOFF §4.3, DESIGN_SYSTEM §10.2): a 60-tick radar sweep, a progress
/// arc with a comet head, and a rotating halo. It reads time from the clock on every tick, so
/// nothing here counts seconds.
struct FocusDial<Center: View>: View {
    var clock: FocusClock
    var estimate: TimeInterval
    var tone: TimerTone
    var metrics: FocusDialMetrics = .board
    @ViewBuilder var center: (_ elapsed: TimeInterval) -> Center

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // A paused clock doesn't change, so it needn't redraw every second.
        let interval: TimeInterval = clock.isRunning ? 1 : 3600
        TimelineView(.periodic(from: clock.runningSince ?? .now, by: interval)) { context in
            let elapsed = clock.elapsed(at: context.date)
            let progress = estimate > 0 ? min(1, elapsed / estimate) : 0
            let second = Int(elapsed) % 60

            ZStack {
                if tone.isMoving && !reduceMotion && metrics.haloOpacity > 0 {
                    DialHalo(tone: tone, metrics: metrics)
                }
                ForEach(0..<60, id: \.self) { index in
                    tick(index, second: second)
                }
                Circle()
                    .fill(Palette.panel)
                    .overlay(Circle().stroke(Palette.border, lineWidth: metrics.ringWidth))
                    .frame(width: metrics.ringRadius * 2, height: metrics.ringRadius * 2)
                arc(progress)
                comet(progress)
                center(elapsed)
            }
            .frame(width: metrics.size, height: metrics.size)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func tick(_ index: Int, second: Int) -> some View {
        let major = index % 5 == 0
        let length = major ? metrics.majorTick : metrics.minorTick
        let distance = (second - index + 60) % 60
        let isHead = tone != .paused && distance == 0
        return Capsule()
            .fill(tickColor(index: index, distance: distance, second: second, major: major))
            .frame(width: metrics.tickWidth, height: length)
            .shadow(color: isHead ? tone.accent.opacity(Sweep.headGlow) : .clear, radius: Sweep.headGlowRadius)
            .offset(y: -(metrics.size - length) / 2)
            .rotationEffect(.degrees(Double(index) * 6))
            .accessibilityHidden(true)
    }

    private func tickColor(index: Int, distance: Int, second: Int, major: Bool) -> Color {
        let rest = Color.white.opacity(major ? Sweep.restMajor : Sweep.restMinor)
        if tone == .paused {
            // Frozen: the ticks up to the paused second stay lit in grey.
            return index <= second ? tone.accent.opacity(Sweep.pausedLit) : Color.white.opacity(Sweep.restMinor)
        }
        if distance == 0 { return .white }
        if distance < Sweep.trail { return tone.accent.opacity(1 - Double(distance) / Sweep.fadeSteps) }
        return rest
    }

    /// Progress moves a fraction of a degree each second, too little to see, yet animating it kept a SwiftUI
    /// animation running every frame. Only whole-percent steps animate, which still covers jumps like +5 min.
    private static func animatedStep(_ progress: Double) -> Double { (progress * 100).rounded() }

    private func arc(_ progress: Double) -> some View {
        let (from, to) = tone.ring
        return Circle()
            .trim(from: 0, to: progress)
            .stroke(
                LinearGradient(colors: [from, to], startPoint: .topLeading, endPoint: .bottomTrailing),
                style: StrokeStyle(lineWidth: metrics.ringWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .frame(width: metrics.ringRadius * 2, height: metrics.ringRadius * 2)
            .animation(reduceMotion ? nil : Motion.slow, value: Self.animatedStep(progress))
            .accessibilityHidden(true)
    }

    // Rotating an offset dot (instead of moving it with x/y) keeps it on the circle while it animates.
    private func comet(_ progress: Double) -> some View {
        let glow = tone.accent.opacity(tone == .paused ? Sweep.pausedCometGlow : Sweep.cometGlow)
        return Circle()
            .fill(tone == .paused ? Palette.textMuted : .white)
            .frame(width: metrics.comet, height: metrics.comet)
            .shadow(color: glow, radius: Sweep.cometGlowRadius)
            .offset(y: -metrics.ringRadius)
            .rotationEffect(.degrees(progress * 360))
            .animation(reduceMotion ? nil : Motion.slow, value: Self.animatedStep(progress))
            .accessibilityHidden(true)
    }
}

private struct DialHalo: View {
    var tone: TimerTone
    var metrics: FocusDialMetrics

    var body: some View {
        let diameter = metrics.size + metrics.haloInset * 2
        LayerEffect<HaloLayerView> { $0.configure(colors: tone.halo, blur: metrics.haloBlur) }
            .frame(width: diameter, height: diameter)
            .opacity(metrics.haloOpacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The blurred conic ring behind the dial. Blur doesn't change under rotation, so the ring is blurred once,
/// rasterized, and the bitmap spins.
private final class HaloLayerView: EffectLayerView {
    private static let spinKey = "spin"

    private let ring = CALayer()
    private let gradient = CAGradientLayer()
    private var blur: CGFloat = 0

    required init(frame: NSRect) {
        super.init(frame: frame)
        gradient.type = .conic
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        gradient.locations = [0, 0.2, 0.4, 0.65, 0.85]
        gradient.masksToBounds = true
        ring.addSublayer(gradient)
        ring.shouldRasterize = true
        layer?.addSublayer(ring)

        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = 2 * Double.pi
        spin.duration = Motion.Period.halo
        ring.add(spin.loopingForever(period: Motion.Period.halo), forKey: Self.spinKey)
    }

    required init?(coder: NSCoder) { nil }

    func configure(colors: (Color, Color), blur: CGFloat) {
        withoutActions {
            gradient.colors = [.clear, colors.0, .clear, colors.1, .clear].map(cgColor)
            if blur != self.blur {
                self.blur = blur
                ring.filters = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: blur]).map { [$0] }
                needsLayout = true
            }
        }
    }

    override func layout() {
        super.layout()
        withoutActions {
            // Room around the ring for the blur to spread into before the layer's edge cuts it off.
            let margin = blur * 3
            ring.bounds = CGRect(x: 0, y: 0, width: bounds.width + margin * 2, height: bounds.height + margin * 2)
            ring.position = CGPoint(x: bounds.midX, y: bounds.midY)
            gradient.frame = CGRect(x: margin, y: margin, width: bounds.width, height: bounds.height)
            gradient.cornerRadius = min(bounds.width, bounds.height) / 2
        }
    }
}

#Preview("FocusDial · Board, every tone") {
    let start = Date.now
    HStack(spacing: Space.s8) {
        ForEach(TimerTone.allCases, id: \.self) { tone in
            FocusDial(
                clock: FocusClock(accumulated: 1_655, runningSince: tone == .paused ? nil : start),
                estimate: 3_600,
                tone: tone
            ) { elapsed in
                Text("\(Int(elapsed / 3_600 * 100))%")
                    .font(Typography.heading)
                    .monospacedDigit()
                    .foregroundStyle(Palette.textPrimary)
            }
        }
    }
    .padding(Space.s8 * 2)
    .background(Palette.bg)
}

#Preview("FocusDial · showcase") {
    FocusDial(
        clock: FocusClock(accumulated: 33, runningSince: .now),
        estimate: 600,
        tone: .live,
        metrics: .showcase
    ) { elapsed in
        OdometerText(TimerFormat.remaining(estimate: 600, elapsed: elapsed))
            .font(Typography.title)
            .foregroundStyle(Palette.textPrimary)
    }
    .padding(Space.s8 * 2)
    .background(Palette.bg)
}
