import KomodoCore
import SwiftUI

/// What the live card shows about the task whose timer is running.
struct LiveTaskModel: Sendable {
    struct Sprint: Sendable {
        var number: Int
        var count: Int
        var length: TimeInterval
        /// The sprint's own clock: work since its start, across tasks.
        var clock: FocusClock
        /// Sprint display is set to Sprint: the card counts the sprint down in pink instead of the estimate.
        var isHero = false

        func elapsed(at date: Date) -> TimeInterval { min(length, clock.elapsed(at: date)) }
        func progress(at date: Date) -> Double { length > 0 ? elapsed(at: date) / length : 0 }
        var lengthLabel: String { TimerFormat.clock(Int(length)) }
    }

    var title: String
    var listLetter: String
    var listColor: ListColor
    /// The email subject or other origin, shown truncated in the header.
    var source: String?
    var estimate: TimeInterval
    /// Elapsed time at the last resume; "Flow" counts from here and resets on Pause or Break.
    var flowStartedAt: TimeInterval
    var sprint: Sprint?
    var linksOpened = 0
    var subtasks: TaskCardModel.Subtasks?
}

/// The live task (DESIGN_SYSTEM §10.2): border beam, status pills, the focus dial beside odometer digits, and
/// the control bar. Everything time-based is derived from the clock each second, including the switch to
/// Time's Up, so nothing here needs to be told when the estimate runs out.
struct LiveTaskCard: View {
    var model: LiveTaskModel
    var clock: FocusClock
    var actions: ControlBarActions

    var body: some View {
        // A paused clock doesn't change, so there's nothing to redraw each second.
        TimelineView(.periodic(from: clock.runningSince ?? .now, by: clock.isRunning ? 1 : 3600)) { context in
            LiveTaskContent(
                model: model, clock: clock, date: context.date, actions: actions)
        }
    }
}

private struct LiveTaskContent: View {
    var model: LiveTaskModel
    var clock: FocusClock
    var date: Date
    var actions: ControlBarActions

    private var elapsed: TimeInterval { clock.elapsed(at: date) }
    /// The sprint when it's the hero; the digits and dial count it instead of the estimate.
    private var heroSprint: LiveTaskModel.Sprint? { model.sprint.flatMap { $0.isHero ? $0 : nil } }

    private var tone: TimerTone {
        TimerTone(
            elapsed: elapsed, estimate: model.estimate, isRunning: clock.isRunning, inSprint: heroSprint != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            header
            Text(model.title)
                .font(Typography.title)
                .tracking(Typography.Tracking.title)
                .foregroundStyle(Palette.textPrimary)
            dialPanel
            footer
            ControlBar(mode: ControlBar.Mode(tone: tone), actions: actions)
        }
        .padding(.horizontal, Space.s4)
        .padding(.top, Space.s4)
        .padding(.bottom, 14)
        .background { LiveCardBackground(tone: tone) }
        .beamBorder(tone, radius: 24)
        .spotlight(SpotlightTint.today, radius: 24, lifts: false)
    }

    private var header: some View {
        HStack(spacing: 7) {
            StatusPill(tone: tone, sprint: model.sprint)
            if clock.isRunning && tone != .timesUp {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill").font(.system(size: 10))
                    Text("Flow " + DurationFormat.short(max(0, elapsed - model.flowStartedAt)))
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.amberText)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(Palette.amber.opacity(0.12), in: Capsule())
            }
            if let source = model.source {
                HStack(spacing: 5) {
                    Image(systemName: "envelope").font(.system(size: 10))
                    Text(source).lineLimit(1).truncationMode(.tail)
                }
                .font(.system(size: 11))
                .foregroundStyle(Palette.textTertiary)
                .padding(.horizontal, Space.s2)
                .frame(height: 24)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: Radius.chip))
                .layoutPriority(-1)
            }
            Spacer(minLength: 0)
            ListBadge(letter: model.listLetter, color: model.listColor)
        }
    }

    /// Dial beside the digits; in a narrow column the digits drop below the dial instead of overflowing.
    private var dialPanel: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 18) {
                dial
                readout.frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(spacing: Space.s3) {
                dial
                readout
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, Space.s4)
        .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
    }

    private var dial: some View {
        let progress = heroSprint?.progress(at: date) ?? (model.estimate > 0 ? min(1, elapsed / model.estimate) : 0)
        return FocusDial(
            clock: heroSprint?.clock ?? clock, estimate: heroSprint?.length ?? model.estimate, tone: tone,
            metrics: .board
        ) { _ in
            VStack(spacing: 1) {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 20, weight: .heavy).monospacedDigit())
                    .tracking(-0.4)
                    .foregroundStyle(Palette.textPrimary)
                Text("OF EST")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(0.9)
                    .foregroundStyle(Palette.textMuted)
            }
        }
    }

    private var readout: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            LiveDigits(tone: tone, text: digits)
            Text(caption)
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(Palette.textSecondary)
            if let sprint = model.sprint {
                SprintDots(sprint: sprint, progress: sprint.progress(at: date))
            }
        }
    }

    private var caption: String {
        let estimate = DurationFormat.short(model.estimate)
        if tone == .timesUp { return "over the \(estimate) estimate" }
        if let sprint = heroSprint {
            return "left of \(sprint.lengthLabel) sprint · \(TimerFormat.clock(Int(elapsed))) on task"
        }
        return "left of \(estimate) · \(TimerFormat.clock(Int(elapsed))) elapsed"
    }

    private var digits: String {
        if let sprint = heroSprint, tone != .timesUp {
            return TimerFormat.remaining(estimate: sprint.length, elapsed: sprint.elapsed(at: date))
        }
        return TimerFormat.remaining(estimate: model.estimate, elapsed: elapsed)
    }

    private var footer: some View {
        HStack(spacing: Space.s2) {
            if model.linksOpened > 0 {
                Label(
                    model.linksOpened == 1 ? "1 link opened" : "\(model.linksOpened) links opened",
                    systemImage: "arrow.up.right.square")
            }
            if model.linksOpened > 0, model.subtasks != nil {
                Text("·").foregroundStyle(Palette.textDisabled)
            }
            if let subtasks = model.subtasks {
                Label("Subtasks \(subtasks.done)/\(subtasks.total)", systemImage: "checklist")
            }
            Spacer(minLength: 0)
            KeyCap("⌘⌥F done")
        }
        .font(.system(size: 11.5))
        .foregroundStyle(Palette.textSecondary)
        .labelStyle(TightLabelStyle())
    }
}

/// `LIVE`, `PAUSED`, `TIME'S UP` or `SPRINT 2 OF 4`, with a pinging dot while the clock moves.
struct StatusPill: View {
    var tone: TimerTone
    var sprint: LiveTaskModel.Sprint?
    /// 24 pt on the Board, 22 pt on the Focus Panel's dial face.
    var height: CGFloat = 24

    private var text: String {
        switch tone {
        case .live, .onBreak: "LIVE"
        case .paused: "PAUSED"
        case .timesUp: "TIME'S UP"
        case .sprint: "SPRINT \(sprint?.number ?? 1) OF \(sprint?.count ?? 4)"
        }
    }

    private var colors: (text: Color, fill: Color) {
        switch tone {
        case .live, .onBreak: (Palette.limeText, Palette.lime.opacity(0.14))
        case .paused: (Palette.textTertiary, Color.white.opacity(0.08))
        case .timesUp: (Palette.redText, Palette.danger.opacity(0.16))
        case .sprint: (Palette.pinkText, Palette.pink.opacity(0.16))
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if tone == .paused {
                Circle().fill(colors.text).frame(width: 6, height: 6)
            } else {
                Circle().fill(colors.text).frame(width: 6, height: 6).ping(colors.text)
            }
            Text(text)
        }
        .font(.system(size: height < 24 ? 10 : 10.5, weight: .heavy))
        .tracking(0.84)
        .foregroundStyle(colors.text)
        .padding(.horizontal, 9)
        .frame(height: height)
        .background(colors.fill, in: Capsule())
        .fixedSize()
    }
}

/// The hero countdown. Overtime shows a smaller `+`, turns danger red and shakes on entering Time's Up.
struct LiveDigits: View {
    var tone: TimerTone
    var text: String
    var font = Typography.timerHero
    /// The overtime `+`, about 0.72 of the digits.
    var plusSize: CGFloat = 35

    var body: some View {
        let isOvertime = text.hasPrefix("+")
        HStack(alignment: .center, spacing: 2) {
            if isOvertime {
                Text("+").font(.system(size: plusSize, weight: .bold))
            }
            OdometerText(isOvertime ? String(text.dropFirst()) : text, colon: tone == .paused ? .blink : .beat)
                .font(font)
                .tracking(Typography.Tracking.timerHero)
        }
        .foregroundStyle(color)
        .shadow(color: glow, radius: tone == .timesUp ? 15 : 17)
        .shake(trigger: tone == .timesUp)
    }

    private var color: Color {
        switch tone {
        case .timesUp: Palette.dangerText
        case .paused: Palette.textSecondary
        case .live, .sprint, .onBreak: Palette.textPrimary
        }
    }

    private var glow: Color {
        switch tone {
        case .timesUp: Palette.danger.opacity(0.6)
        case .paused: .clear
        case .sprint: Palette.pink.opacity(0.45)
        case .live, .onBreak: Palette.lime.opacity(0.4)
        }
    }
}

/// Four 18 pt sprint bars: finished ones lime and glowing, the current one filling.
private struct SprintDots: View {
    var sprint: LiveTaskModel.Sprint
    var progress: Double

    var body: some View {
        HStack(spacing: Space.s2) {
            HStack(spacing: 4) {
                ForEach(1...max(1, sprint.count), id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .overlay(alignment: .leading) {
                            GeometryReader { geo in
                                Capsule()
                                    .fill(Palette.lime)
                                    .frame(width: geo.size.width * fill(for: index))
                            }
                        }
                        .frame(width: 18, height: 5)
                        .shadow(color: index < sprint.number ? Palette.lime.opacity(0.7) : .clear, radius: 4)
                }
            }
            Text("Sprint \(sprint.number) of \(sprint.count)")
        }
        .font(.system(size: 11.5))
        .foregroundStyle(Palette.textSecondary)
    }

    private func fill(for index: Int) -> Double {
        if index < sprint.number { return 1 }
        if index == sprint.number { return min(1, max(0, progress)) }
        return 0
    }
}

/// The tone's two soft washes over the card's dark base.
private struct LiveCardBackground: View {
    var tone: TimerTone

    var body: some View {
        let washes = self.washes
        ZStack {
            Palette.panel
            EllipticalGradient(
                colors: [washes.0, .clear], center: .topLeading, startRadiusFraction: 0, endRadiusFraction: 1.1)
            EllipticalGradient(
                colors: [washes.1, .clear], center: .bottomTrailing, startRadiusFraction: 0, endRadiusFraction: 0.9)
        }
    }

    private var washes: (Color, Color) {
        switch tone {
        case .live: (Palette.teal.opacity(0.18), Palette.lime.opacity(0.1))
        case .sprint: (Palette.pink.opacity(0.18), Palette.lime.opacity(0.08))
        case .paused: (Color.white.opacity(0.04), .clear)
        case .timesUp: (Palette.danger.opacity(0.2), Palette.ember.opacity(0.1))
        case .onBreak: (Palette.green.opacity(0.18), .clear)
        }
    }
}

struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.font(.system(size: 10.5))
            configuration.title
        }
    }
}

enum LiveTaskSamples {
    static let designReview = LiveTaskModel(
        title: "Design review prep with Apurva", listLetter: "W", listColor: .lime, source: "Re: Design review",
        estimate: 3_600, flowStartedAt: 1_533, linksOpened: 2, subtasks: .init(done: 2, total: 3))

    static var sprint: LiveTaskModel {
        var model = designReview
        model.sprint = .init(
            number: 2, count: 4, length: 1_500, clock: FocusClock(accumulated: 900, runningSince: .now), isHero: true)
        return model
    }
}

#Preview("Live task card") {
    let now = Date.now
    ScrollView {
        VStack(spacing: Space.s6) {
            LiveTaskCard(
                model: LiveTaskSamples.designReview,
                clock: FocusClock(accumulated: 3_033, runningSince: now), actions: ControlBarActions())
            LiveTaskCard(
                model: LiveTaskSamples.sprint,
                clock: FocusClock(accumulated: 3_033, runningSince: now), actions: ControlBarActions())
            LiveTaskCard(
                model: LiveTaskSamples.designReview, clock: FocusClock(accumulated: 3_033),
                actions: ControlBarActions())
            LiveTaskCard(
                model: LiveTaskSamples.designReview,
                clock: FocusClock(accumulated: 3_734, runningSince: now), actions: ControlBarActions())
        }
        .padding(Space.s8)
    }
    .frame(width: 540, height: 900)
    .background(Palette.bg)
}
