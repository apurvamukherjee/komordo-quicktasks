import KomodoCore
import SwiftUI

/// The Focus Panel's live task (DESIGN_SYSTEM §13.8, FocusPanel.dc.html): the 236 pt dial with the countdown on
/// its face, the title, Flow, sprint and links chips, and the control bar. Paused and Time's Up come from the
/// clock, as on the Board's live card; in Sprint display the dial counts the sprint in pink (FocusStates ④).
struct FocusHeroCard: View {
    var model: LiveTaskModel
    var clock: FocusClock
    var actions: ControlBarActions

    var body: some View {
        // A paused clock doesn't change, so there's nothing to redraw each second.
        TimelineView(.periodic(from: clock.runningSince ?? .now, by: clock.isRunning ? 1 : 3600)) { context in
            FocusHeroContent(model: model, clock: clock, date: context.date, actions: actions)
        }
    }
}

private struct FocusHeroContent: View {
    var model: LiveTaskModel
    var clock: FocusClock
    var date: Date
    var actions: ControlBarActions

    private var elapsed: TimeInterval { clock.elapsed(at: date) }
    private var heroSprint: LiveTaskModel.Sprint? { model.sprint.flatMap { $0.isHero ? $0 : nil } }

    private var tone: TimerTone {
        TimerTone(
            elapsed: elapsed, estimate: model.estimate, isRunning: clock.isRunning,
            inSprint: model.sprint?.isHero == true)
    }

    var body: some View {
        VStack(spacing: 0) {
            FocusDial(
                clock: heroSprint?.clock ?? clock, estimate: heroSprint?.length ?? model.estimate, tone: tone,
                metrics: .panel
            ) { _ in face }
            Text(model.title)
                .font(.system(size: 17, weight: .bold))
                .tracking(-0.26)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .padding(.top, Space.s3)
            Group {
                if let sprint = heroSprint, tone == .sprint { sprintBars(sprint) } else { chips }
            }
            .padding(.top, 9)
            // WeightedHStack fills a concrete height, and outside a scroll view the panel offers one.
            ControlBar(mode: ControlBar.Mode(tone: tone), actions: actions, tileHeight: 54)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
        }
        .padding(.horizontal, 14)
        .padding(.top, Space.s4)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background { FocusHeroBackground(tone: tone) }
        .beamBorder(tone, radius: 24)
        .spotlight(SpotlightTint.today, radius: 24, lifts: false)
    }

    /// `.fp-face`: the pill, the countdown and two captions on a dark disc inset 34 pt from the dial's edge.
    private var face: some View {
        VStack(spacing: 6) {
            StatusPill(tone: tone, sprint: model.sprint, height: 22)
            // Past the estimate, Time's Up counts the task's overtime even in Sprint display.
            let sprint = tone == .timesUp ? nil : heroSprint
            let text =
                sprint.map { TimerFormat.remaining(estimate: $0.length, elapsed: $0.elapsed(at: date)) }
                ?? TimerFormat.remaining(estimate: model.estimate, elapsed: elapsed)
            // Hours don't fit the face at full size, so the canvas drops to 38 pt past an hour.
            LiveDigits(
                tone: tone, text: text,
                font: text.count > 6 ? .system(size: 38, weight: .bold).monospacedDigit() : Typography.timerHero,
                plusSize: 36)
            VStack(spacing: 2) {
                Text(caption)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(tone == .timesUp ? Palette.redText : Palette.textTertiary)
                Text("\(TimerFormat.clock(Int(elapsed))) \(heroSprint == nil ? "elapsed" : "on task")")
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Palette.textMuted)
            }
        }
        .frame(width: 168, height: 168)
        .background {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Palette.cardTop, Palette.bg], center: UnitPoint(x: 0.5, y: 0.28), startRadius: 0,
                        endRadius: 114)
                )
                .overlay(Circle().strokeBorder(Color.white.opacity(0.03), lineWidth: 1))
                .shadow(color: .black.opacity(0.85), radius: 17)
        }
    }

    private var caption: String {
        let estimate = DurationFormat.short(model.estimate)
        if tone == .timesUp { return "over the \(estimate) estimate" }
        if let sprint = heroSprint { return "left of \(sprint.lengthLabel) sprint" }
        return "left of \(estimate)"
    }

    /// Sprint display: four pink capsules filling with the sprints, and "Sprint 2 of 4 · 25:00 sprint".
    private func sprintBars(_ sprint: LiveTaskModel.Sprint) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(1...sprint.count, id: \.self) { index in
                    let fill = index < sprint.number ? 1 : index == sprint.number ? sprint.progress(at: date) : 0
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Palette.pink, Palette.pinkText], startPoint: .leading,
                                        endPoint: .trailing)
                                )
                                .frame(width: 34 * fill)
                                .shadow(color: Palette.pink.opacity(0.8), radius: 5)
                        }
                        .frame(width: 34, height: 8)
                }
            }
            // The sprint length drops before the text truncates, at 340 pt rather than the artboard's 380.
            ViewThatFits(in: .horizontal) {
                Text("Sprint \(sprint.number) of \(sprint.count) · \(sprint.lengthLabel) sprint")
                Text("Sprint \(sprint.number) of \(sprint.count)")
            }
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(Palette.pinkText)
            .lineLimit(1)
        }
        .frame(height: 22)
        .accessibilityElement(children: .combine)
    }

    /// Task display with Pomodoros on (FocusPanel.png): four dots, done ones lime, and "Sprint 2 of 4".
    private func sprintChip(_ sprint: LiveTaskModel.Sprint) -> some View {
        HStack(spacing: 4) {
            HStack(spacing: 3) {
                ForEach(1...sprint.count, id: \.self) { index in
                    Circle()
                        .fill(index <= sprint.number ? Palette.lime : Color.white.opacity(0.18))
                        .opacity(index == sprint.number ? 0.7 : 1)
                        .frame(width: 6, height: 6)
                        .shadow(color: index < sprint.number ? Palette.lime.opacity(0.8) : .clear, radius: 3)
                }
            }
            Text("Sprint \(sprint.number) of \(sprint.count)")
        }
        .foregroundStyle(Palette.textTertiary)
        .panelChip(tint: nil)
        .help("Pomodoro sprint \(sprint.number) of \(sprint.count)")
    }

    /// Flow, the sprint and the links, as FocusPanel.png lines them up. The 380 pt artboard fits all three; at
    /// 340 pt the links chip gives way first.
    private var chips: some View {
        ViewThatFits(in: .horizontal) {
            chipRow(showsLinks: true)
            chipRow(showsLinks: false)
        }
        .frame(height: 22)
    }

    private func chipRow(showsLinks: Bool) -> some View {
        HStack(spacing: 5) {
            if tone == .live {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").font(.system(size: 9))
                    Text("Flow " + DurationFormat.short(max(0, elapsed - model.flowStartedAt)))
                }
                .foregroundStyle(Palette.amberText)
                .panelChip(tint: Palette.amber)
            }
            if let sprint = model.sprint, !sprint.isHero { sprintChip(sprint) }
            if showsLinks, model.linksOpened > 0 {
                Label(
                    model.linksOpened == 1 ? "1 link opened" : "\(model.linksOpened) links opened",
                    systemImage: "arrow.up.right.square"
                )
                .labelStyle(TightLabelStyle())
                .foregroundStyle(Palette.textTertiary)
                .panelChip(tint: nil)
            }
        }
        .fixedSize()
    }
}

extension View {
    /// `.fp-chip`: a 22 pt chip, neutral or washed in a tint.
    fileprivate func panelChip(tint: Color?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        return font(.system(size: 10.5, weight: .semibold))
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(tint.map { $0.opacity(0.12) } ?? Color.white.opacity(0.05), in: shape)
            .overlay(shape.strokeBorder(tint.map { $0.opacity(0.3) } ?? Color.white.opacity(0.07), lineWidth: 1))
            .fixedSize()
    }
}

/// The tone's two washes, one from the top and one from the bottom right, over the card's dark base.
private struct FocusHeroBackground: View {
    var tone: TimerTone

    var body: some View {
        let washes = self.washes
        ZStack {
            Palette.panel
            EllipticalGradient(
                colors: [washes.0, .clear], center: .top, startRadiusFraction: 0, endRadiusFraction: 0.6)
            EllipticalGradient(
                colors: [washes.1, .clear], center: .bottomTrailing, startRadiusFraction: 0, endRadiusFraction: 0.6)
        }
    }

    private var washes: (Color, Color) {
        switch tone {
        case .live: (Palette.teal.opacity(0.2), Palette.lime.opacity(0.1))
        case .sprint: (Palette.pink.opacity(0.18), Palette.lime.opacity(0.08))
        case .paused: (Color.white.opacity(0.04), .clear)
        case .timesUp: (Palette.danger.opacity(0.22), Palette.ember.opacity(0.1))
        case .onBreak: (Palette.green.opacity(0.2), .clear)
        }
    }
}

#Preview("Focus hero") {
    let now = Date.now
    ScrollView {
        HStack(alignment: .top, spacing: Space.s5) {
            FocusHeroCard(
                model: LiveTaskSamples.designReview, clock: FocusClock(accumulated: 3_033, runningSince: now),
                actions: ControlBarActions())
            FocusHeroCard(
                model: LiveTaskSamples.designReview, clock: FocusClock(accumulated: 3_033),
                actions: ControlBarActions())
            FocusHeroCard(
                model: LiveTaskSamples.designReview, clock: FocusClock(accumulated: 3_734, runningSince: now),
                actions: ControlBarActions())
        }
        .frame(width: 3 * 312 + 2 * Space.s5)
        .padding(Space.s6)
    }
    .frame(width: 1060, height: 520)
    .background(Palette.bg)
}
