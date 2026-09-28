import KomodoCore
import SwiftUI

/// The live card's height, so a break or the celebration takes its place without moving the list below.
private let heroHeight: CGFloat = 399

/// A break in the Focus Panel (DESIGN_SYSTEM §13.8, FocusStates ⑤): a breathing circle inside a ring that fills
/// as the break runs, the countdown, and what comes next. Once it runs out, Resume takes over; nothing restarts
/// on its own (FEATURES §4.11).
struct FocusBreakCard: View {
    var endsAt: Date
    var length: TimeInterval
    var upNext: String
    var onSkip: () -> Void
    var onAddTwoMinutes: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(remaining: max(0, endsAt.timeIntervalSince(context.date)), at: context.date)
        }
    }

    private func content(remaining: TimeInterval, at date: Date) -> some View {
        let isOver = remaining <= 0
        return VStack(spacing: 0) {
            Label("BREAK", systemImage: "cup.and.saucer")
                .labelStyle(TightLabelStyle())
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Palette.greenText)
                .padding(.horizontal, 9)
                .frame(height: 22)
                .background(Palette.green.opacity(0.14), in: Capsule())
            stage(remaining: remaining, isOver: isOver, at: date)
                .padding(.top, 4)
            Text("Stretch, water, eyes off the screen.")
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 6)
            (Text("Up next: ") + Text(upNext).bold().foregroundColor(Palette.textPrimary))
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.textTertiary)
                .lineLimit(1)
                .padding(.top, 4)
            Spacer(minLength: Space.s3)
            if isOver {
                Button(action: onSkip) {
                    Label("Resume \(upNext)", systemImage: "play.fill").lineLimit(1).frame(maxWidth: .infinity)
                }
                .buttonStyle(.komodo(.primary, size: .large))
            } else {
                HStack(spacing: Space.s2) {
                    Button(action: onSkip) { Text("Skip break").frame(maxWidth: .infinity) }
                        .help("Skip break ⌘⌥B")
                    Button(action: onAddTwoMinutes) { Text("+2 min").frame(maxWidth: .infinity) }
                }
                .buttonStyle(.komodo(.secondary, size: .large))
            }
        }
        .padding(.horizontal, Space.s4)
        .padding(.top, Space.s4)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .frame(height: heroHeight)
        .background {
            ZStack {
                Palette.panel
                EllipticalGradient(
                    colors: [Palette.green.opacity(0.2), .clear], center: .top, startRadiusFraction: 0,
                    endRadiusFraction: 0.62)
            }
        }
        .beamBorder(.onBreak, radius: 24)
        .spotlight(SpotlightTint.success, radius: 24, lifts: false)
    }

    private func stage(remaining: TimeInterval, isOver: Bool, at date: Date) -> some View {
        let progress = length > 0 ? 1 - remaining / length : 1
        // Four seconds in, four out, in step with the circle's layer animation.
        let breathingIn = Int(date.timeIntervalSinceReferenceDate / (Motion.Period.breath / 2)) % 2 == 0
        return ZStack {
            BreathingCircle()
            Circle().stroke(Palette.green.opacity(0.12), lineWidth: 3).frame(width: 220, height: 220)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Palette.greenText, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 220, height: 220)
                .shadow(color: Palette.green.opacity(0.8), radius: 6)
            VStack(spacing: 4) {
                Text(isOver ? "Break's over" : breathingIn ? "Breathe in" : "Breathe out")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.72)
                    .foregroundStyle(Palette.mint)
                Text(TimerFormat.clock(Int(remaining.rounded(.up))))
                    .font(Typography.timerHero)
                    .tracking(Typography.Tracking.timerHero)
                    .foregroundStyle(Palette.greenText)
                    .shadow(color: Palette.green.opacity(0.7), radius: 15)
                    .contentTransition(.numericText(countsDown: true))
                    .accessibilityAddTraits(.updatesFrequently)
                Text("of \(TimerFormat.clock(Int(length))) break")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(Palette.textMuted)
            }
        }
        .frame(width: 236, height: 236)
    }
}

/// Only timed tasks are left (FocusStates ⑥): a calm blue card naming the next one, with Start early.
struct FocusScheduledCard: View {
    var title: String
    var time: String
    var onStartEarly: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 23, style: .continuous)
        VStack(spacing: 0) {
            CalmIcon()
            Text("FOCUS QUEUE IS CLEAR")
                .font(Typography.label)
                .tracking(Typography.Tracking.label)
                .foregroundStyle(Palette.blueText)
                .padding(.top, 18)
            Text("Next: \(title) at \(time)")
                .font(.system(size: 20, weight: .heavy))
                .tracking(-0.4)
                .lineSpacing(1)
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, Space.s2)
            Text("It joins the queue on time and a reminder fires. Nothing starts on its own before then.")
                .font(.system(size: 12.5))
                .lineSpacing(2)
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: 270)
                .padding(.top, 6)
            Button(action: onStartEarly) {
                Label("Start early", systemImage: "bolt.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.komodo(.primary, size: .large))
            .padding(.top, 18)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Space.s5)
        .padding(.top, 26)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                Palette.panel
                EllipticalGradient(
                    colors: [Palette.blue.opacity(0.16), .clear], center: .top, startRadiusFraction: 0,
                    endRadiusFraction: 0.65)
            }
        }
        .clipShape(shape)
        .padding(1)
        .background(
            LinearGradient(
                stops: [
                    .init(color: Palette.blue.opacity(0.6), location: 0),
                    .init(color: .white.opacity(0.06), location: 0.48),
                    .init(color: Palette.blue.opacity(0.28), location: 1),
                ], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .shadow(color: Palette.blue.opacity(0.3), radius: 30)
        .spotlight(SpotlightTint.week, radius: 24, lifts: false)
    }
}

/// The end of the queue (FocusStates ⑦): "You won the day." with tasks done, time focused and how the estimates
/// held up. The streak and the unfinished tasks are P1 and arrive with the Day summary (DESIGN_SYSTEM §13.11).
struct FocusWonCard: View {
    var date: Date
    var done: Int
    var focused: TimeInterval
    var summary: DaySummary
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "trophy")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Palette.onAmber)
                    .frame(width: 48, height: 48)
                    .background(
                        LinearGradient(
                            colors: [Palette.amber, Palette.lime], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: Space.s4, style: .continuous)
                    )
                    .shadow(color: Palette.amber.opacity(0.6), radius: 15, y: 10)
                    .padding(.bottom, 6)
                Text("You won the day.")
                    .font(.system(size: 27, weight: .heavy))
                    .tracking(-0.8)
                    .foregroundStyle(Palette.textPrimary)
                let day = date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
                Text("\(day) · the Focus queue is empty.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
            }
            WeightedHStack(weights: [1, 1, 1], spacing: Space.s2) {
                stat("\(done)", "tasks", tint: SpotlightTint.today)
                stat(DurationFormat.compact(focused), "focused", tint: SpotlightTint.info)
                stat(
                    summary.onEstimate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—", "on est.",
                    tint: SpotlightTint.today, isHighlighted: true)
            }
            if summary.measured > 0 { accuracy }
            HStack(spacing: Space.s2) {
                Button {
                } label: {
                    Text("See reports").frame(maxWidth: .infinity)
                }
                .buttonStyle(.komodo(.secondary, size: .large))
                .disabled(true)
                .help("Reports arrive in a later milestone")
                Button(action: onDone) { Text("Done").frame(maxWidth: .infinity) }
                    .buttonStyle(.komodo(.primary, size: .large))
                    .help("Close the summary")
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Palette.panel
                EllipticalGradient(
                    colors: [Palette.amber.opacity(0.16), .clear], center: .top, startRadiusFraction: 0,
                    endRadiusFraction: 0.6)
                EllipticalGradient(
                    colors: [Palette.teal.opacity(0.08), .clear], center: .bottomLeading, startRadiusFraction: 0,
                    endRadiusFraction: 0.5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22.5, style: .continuous))
        .padding(1.5)
        .background(
            LinearGradient(
                colors: [Palette.teal, Palette.lime, Palette.amber, Palette.pink], startPoint: .topLeading,
                endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .shadow(color: Palette.amber.opacity(0.35), radius: 40)
        .spotlight(SpotlightTint.review, radius: 24, lifts: false)
    }

    private func stat(_ value: String, _ label: String, tint: Color, isHighlighted: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.system(size: 22, weight: .heavy).monospacedDigit())
                .tracking(-0.66)
                .foregroundStyle(isHighlighted ? Palette.limeText : Palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label).font(.system(size: 11)).foregroundStyle(Palette.textSecondary)
        }
        .padding(Space.s3)
        // Fill the row's height too, so a value that scales down doesn't leave its tile shorter.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .spotlight(tint, radius: Radius.tile, lifts: false) {
            if isHighlighted {
                shape.fill(Palette.lime.opacity(0.08)).overlay(shape.strokeBorder(Palette.lime.opacity(0.2)))
            } else {
                TileSurface(radius: Radius.tile)
            }
        }
    }

    /// Early, on time and late as one bar split by count, with a legend.
    private var accuracy: some View {
        let parts: [(Int, Color, String)] = [
            (summary.early, Palette.green, "Early"), (summary.onTime, Palette.lime, "On time"),
            (summary.late, Palette.amber, "Late"),
        ]
        // Empty parts leave the bar, or they'd still take a gap.
        let filled = parts.filter { $0.0 > 0 }
        return VStack(alignment: .leading, spacing: Space.s2) {
            WeightedHStack(weights: filled.map { CGFloat($0.0) }, spacing: 3) {
                ForEach(filled.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4, style: .continuous).fill(filled[index].1).frame(height: 8)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Space.s3) {
                ForEach(parts.indices, id: \.self) { index in
                    HStack(spacing: 5) {
                        Circle().fill(parts[index].1).frame(width: 7, height: 7)
                        Text("\(parts[index].2) \(parts[index].0)")
                    }
                }
            }
            .font(.system(size: 12).monospacedDigit())
            .foregroundStyle(Palette.textTertiary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The break's circle breathing in and out, with a fainter ring swelling past it. Drawn in Core Animation so the
/// loop costs nothing per frame; still under Reduce Motion.
private struct BreathingCircle: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        LayerEffect<BreathingLayerView> {
            $0.configure(
                glow: Palette.green, fill: Palette.green, edge: Palette.greenText, base: Palette.panel,
                animates: !reduceMotion)
        }
        .frame(width: 236, height: 236)
        .accessibilityHidden(true)
    }
}

private final class BreathingLayerView: EffectLayerView {
    private let glow = CAGradientLayer()
    private let circle = CAGradientLayer()
    private let ring = CALayer()
    private var animates: Bool?

    required init(frame: NSRect) {
        super.init(frame: frame)
        for layer in [glow, circle] {
            layer.type = .radial
            layer.startPoint = CGPoint(x: 0.5, y: 0.5)
            layer.endPoint = CGPoint(x: 1, y: 1)
        }
        circle.startPoint = CGPoint(x: 0.5, y: 0.35)
        circle.borderWidth = 1.5
        circle.shadowRadius = 20
        circle.shadowOpacity = 0.55
        circle.shadowOffset = .zero
        ring.borderWidth = 1
        for sublayer in [glow, ring, circle] { layer?.addSublayer(sublayer) }
    }

    required init?(coder: NSCoder) { nil }

    func configure(glow glowColor: Color, fill: Color, edge: Color, base: Color, animates: Bool) {
        withoutActions {
            glow.colors = [cgColor(glowColor.opacity(0.4)), cgColor(.clear)]
            glow.locations = [0, 0.66]
            circle.colors = [cgColor(fill.opacity(0.16)), cgColor(base.opacity(0.9))]
            circle.locations = [0, 0.7]
            circle.borderColor = cgColor(edge.opacity(0.55))
            circle.shadowColor = cgColor(glowColor)
            ring.borderColor = cgColor(edge.opacity(0.25))
        }
        guard animates != self.animates else { return }
        self.animates = animates
        for sublayer in [glow, circle, ring] { sublayer.removeAllAnimations() }
        guard animates else { return }
        let breathe = scale(from: 1, to: 1.12)
        glow.add(breathe, forKey: "breathe")
        circle.add(breathe, forKey: "breathe")
        let swell = CAAnimationGroup()
        swell.animations = [scale(from: 1.02, to: 1.26), fade(from: 0.2, to: 0.8)]
        swell.duration = Motion.Period.breath / 2
        swell.autoreverses = true
        ring.add(swell.loopingForever(period: Motion.Period.breath), forKey: "swell")
    }

    private func scale(from: Double, to: Double) -> CAAnimation {
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = Motion.Period.breath / 2
        animation.autoreverses = true
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return animation.loopingForever(period: Motion.Period.breath)
    }

    private func fade(from: Double, to: Double) -> CAAnimation {
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = from
        animation.toValue = to
        animation.duration = Motion.Period.breath / 2
        return animation
    }

    override func layout() {
        super.layout()
        withoutActions {
            glow.frame = bounds.insetBy(dx: 6, dy: 6)
            circle.frame = bounds.insetBy(dx: 30, dy: 30)
            ring.frame = circle.frame
            for layer in [glow, circle, ring] {
                layer.cornerRadius = layer.bounds.width / 2
                layer.position = CGPoint(x: bounds.midX, y: bounds.midY)
            }
        }
    }
}

/// `.fp-calm`: the calendar-clock tile with a breathing blue glow and a dot orbiting a dashed ring.
private struct CalmIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LayerEffect<OrbitLayerView> {
                $0.configure(glow: Palette.blue, ring: Palette.blueText, animates: !reduceMotion)
            }
            .frame(width: 116, height: 116)
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Palette.blueText)
                .frame(width: 64, height: 64)
                .background(
                    LinearGradient(
                        colors: [Palette.blue.opacity(0.3), Palette.blue.opacity(0.08)], startPoint: .top,
                        endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: Space.s5, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Space.s5, style: .continuous)
                        .strokeBorder(Palette.blueText.opacity(0.4), lineWidth: 1))
        }
        .frame(width: 96, height: 96)
        .accessibilityHidden(true)
    }
}

private final class OrbitLayerView: EffectLayerView {
    private let glow = CAGradientLayer()
    private let orbit = CALayer()
    private let ring = CAShapeLayer()
    private let dot = CALayer()
    private var animates: Bool?

    required init(frame: NSRect) {
        super.init(frame: frame)
        glow.type = .radial
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        glow.locations = [0, 0.65]
        ring.fillColor = nil
        ring.lineWidth = 1
        ring.lineDashPattern = [3, 3]
        dot.shadowOffset = .zero
        dot.shadowRadius = 6
        dot.shadowOpacity = 0.8
        orbit.addSublayer(ring)
        orbit.addSublayer(dot)
        for sublayer in [glow, orbit] { layer?.addSublayer(sublayer) }
    }

    required init?(coder: NSCoder) { nil }

    func configure(glow glowColor: Color, ring ringColor: Color, animates: Bool) {
        withoutActions {
            glow.colors = [cgColor(glowColor.opacity(0.4)), cgColor(.clear)]
            ring.strokeColor = cgColor(ringColor.opacity(0.3))
            dot.backgroundColor = cgColor(ringColor)
            dot.shadowColor = cgColor(glowColor)
        }
        guard animates != self.animates else { return }
        self.animates = animates
        for sublayer in [glow, orbit] { sublayer.removeAllAnimations() }
        guard animates else { return }
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = 2 * Double.pi
        spin.duration = Motion.Period.orbit
        orbit.add(spin.loopingForever(period: Motion.Period.orbit), forKey: "spin")
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.93
        scale.toValue = 1.07
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.5
        fade.toValue = 1
        let breathe = CAAnimationGroup()
        breathe.animations = [scale, fade]
        breathe.duration = Motion.Period.calmGlow / 2
        breathe.autoreverses = true
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glow.add(breathe.loopingForever(period: Motion.Period.calmGlow), forKey: "breathe")
    }

    override func layout() {
        super.layout()
        withoutActions {
            glow.frame = bounds
            glow.cornerRadius = bounds.width / 2
            // The ring is the 96 pt tile area; the extra room lets the glow spread past it.
            let ringFrame = bounds.insetBy(dx: 10, dy: 10)
            orbit.frame = ringFrame
            ring.frame = orbit.bounds
            ring.path = CGPath(ellipseIn: orbit.bounds, transform: nil)
            dot.frame = CGRect(x: orbit.bounds.midX - 4, y: -4, width: 8, height: 8)
            dot.cornerRadius = 4
        }
    }
}

#Preview("Focus state cards") {
    // Four early, one on time and two late, as on the canvas.
    let now = Date.now
    let taken: [TimeInterval] = [1_800, 2_400, 3_000, 2_000, 3_700, 4_600, 5_000]
    let sampleSummary = DaySummary(
        doneToday: taken.enumerated().map { index, seconds in
            TaskItem(
                id: "done-\(index)", listID: "work", title: "Done \(index)", bucket: .today, rank: 0,
                estimate: 3_600, completedAt: now, sessions: [WorkSession(start: now - seconds, end: now)])
        }, now: now)
    ScrollView {
        HStack(alignment: .top, spacing: Space.s5) {
            FocusBreakCard(
                endsAt: .now.addingTimeInterval(252), length: 300, upNext: "Design review prep with Apurva",
                onSkip: {}, onAddTwoMinutes: {})
            FocusScheduledCard(title: "Wireframes", time: "11:00 AM", onStartEarly: {})
            FocusWonCard(date: .now, done: 7, focused: 20_400, summary: sampleSummary, onDone: {})
        }
        .frame(width: 3 * 312 + 2 * Space.s5)
        .padding(Space.s6)
    }
    .frame(width: 1060, height: 560)
    .background(Palette.bg)
}
