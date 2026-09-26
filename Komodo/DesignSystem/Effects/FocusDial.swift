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
                if tone.isMoving && !reduceMotion {
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
            .animation(reduceMotion ? nil : Motion.slow, value: progress)
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
            .animation(reduceMotion ? nil : Motion.slow, value: progress)
            .accessibilityHidden(true)
    }
}

private struct DialHalo: View {
    var tone: TimerTone
    var metrics: FocusDialMetrics

    var body: some View {
        let (first, second) = tone.halo
        let diameter = metrics.size + metrics.haloInset * 2
        TimelineView(.animation) { context in
            let turns = context.date.timeIntervalSinceReferenceDate / Motion.Period.halo
            Circle()
                .fill(
                    AngularGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: first, location: 0.2),
                            .init(color: .clear, location: 0.4),
                            .init(color: second, location: 0.65),
                            .init(color: .clear, location: 0.85),
                        ],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    )
                )
                .rotationEffect(.degrees(turns.truncatingRemainder(dividingBy: 1) * 360))
        }
        .frame(width: diameter, height: diameter)
        .blur(radius: metrics.haloBlur)
        .opacity(metrics.haloOpacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
