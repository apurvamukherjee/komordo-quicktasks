import KomodoCore
import SwiftUI

/// The floating timer (DESIGN_SYSTEM §10.5, FEATURES §4.9): a 40 pt glass pill with the live task's ring, title
/// and time, and a progress line along its bottom edge. Hovering slides in the controls; Time's Up puts +5 and
/// Done inline, a break counts down in green, and ⌘⇧P ripples it.
struct FloatingTimerView: View {
    enum DragPhase {
        case changed
        case ended
    }

    var store: BoardStore
    /// The window moves itself from the mouse's screen position, so the pill only reports the drag.
    var onDrag: (DragPhase) -> Void = { _ in }

    @State private var isHovered = false
    @State private var isShowingNotes = false

    var body: some View {
        let clock = store.liveTask.map { store.focusClock(for: $0) }
        // Ticks while time moves; a paused or waiting pill has nothing to redraw each second.
        let moving = clock?.isRunning == true || store.breakEndsAtWallClock != nil
        TimelineView(.periodic(from: clock?.runningSince ?? .now, by: moving ? 1 : 3600)) { context in
            pill(at: context.date, clock: clock)
        }
        .padding(Space.s6)
        .preferredColorScheme(.dark)
    }

    private func pill(at date: Date, clock: FocusClock?) -> some View {
        let state = PillState(store: store, clock: clock, at: date)
        let actions = state.controls(store: store) { isShowingNotes = true }
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        return HStack(spacing: 10) {
            content(state, clock: clock)
            if isHovered, !actions.isEmpty {
                Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 18).padding(.trailing, -3)
                controls(actions)
                    .transition(.opacity.combined(with: .scale(scale: 0.55, anchor: .leading)))
            }
        }
        .padding(.leading, 11)
        .padding(.trailing, 14)
        .frame(minWidth: Layout.floatingTimerMinWidth, minHeight: Layout.floatingTimerHeight)
        .fixedSize()
        .background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(state.fill)
            }
        }
        .overlay(shape.strokeBorder(state.edge, lineWidth: state.edgeWidth))
        .overlay(alignment: .bottom) { ProgressLine(progress: state.progress, fill: state.line) }
        .overlay { LocatorRipple(trigger: store.locatorPings) }
        .background { PillGlow(color: state.glow, breathes: state.breathes) }
        .contentShape(shape)
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { _ in onDrag(.changed) }
                .onEnded { _ in onDrag(.ended) }
        )
        .onHover { hovering in withAnimation(Motion.spring) { isHovered = hovering } }
        .popover(isPresented: $isShowingNotes, arrowEdge: .bottom) {
            if let live = store.liveTask {
                InspectorNotes(store: store, task: live)
                    .frame(width: Layout.inspectorMin)
                    .padding(Space.s3)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Floating timer")
    }

    @ViewBuilder private func content(_ state: PillState, clock: FocusClock?) -> some View {
        switch state.kind {
        case .live(let tone, let title, let time):
            leading(tone: tone, clock: clock)
            titleText(title)
            OdometerText(time, colon: tone == .paused ? .blink : .beat)
                .font(Typography.timerPill)
                .tracking(-0.15)
                .foregroundStyle(tone == .timesUp ? Palette.redText : tone == .paused ? Palette.textMuted : .white)
                .shadow(color: tone == .live ? Palette.lime.opacity(0.6) : .clear, radius: 7)
                .shake(trigger: tone == .timesUp)
            if tone == .timesUp {
                Rectangle().fill(Color.white.opacity(0.14)).frame(width: 1, height: 18)
                Button("+5") { store.extendEstimate(by: 300) }
                    .buttonStyle(PillTextButtonStyle(isPrimary: false))
                    .help("Add 5 minutes to the estimate")
                Button("Done", action: store.completeLive)
                    .buttonStyle(PillTextButtonStyle(isPrimary: true))
                    .help("Done ⌘⌥F")
            }
        case .onBreak(let time, let next):
            Image(systemName: "cup.and.saucer").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.greenText)
            Text("Break").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.greenText)
            Text(time)
                .font(Typography.timerPill)
                .foregroundStyle(Palette.greenText)
                .contentTransition(.numericText(countsDown: true))
            Text("then \(next)")
                .font(.system(size: 12))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: 200, alignment: .leading)
        case .waiting(let title, let time):
            Image(systemName: "calendar.badge.clock").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.blueText)
            titleText("Next: \(title)")
            Text(time).font(Typography.timerPill).foregroundStyle(Palette.blueText)
        case .idle:
            Image(systemName: "sun.max").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.limeText)
            titleText("Focus mode")
        }
    }

    @ViewBuilder private func leading(tone: TimerTone, clock: FocusClock?) -> some View {
        switch tone {
        case .paused:
            Image(systemName: "pause.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(
                Palette.textSecondary
            )
            .frame(width: 18, height: 18)
        case .timesUp:
            Image(systemName: "timer").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.redText)
                .frame(width: 18, height: 18)
        case .live, .sprint, .onBreak:
            if let clock, let estimate = store.liveTask?.estimate {
                FocusDial(clock: clock, estimate: estimate, tone: tone, metrics: .pill) { _ in EmptyView() }
            }
        }
    }

    private func titleText(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Palette.textBody)
            .lineLimit(1)
            // DESIGN_SYSTEM §10.5 caps the title at 200 pt.
            .frame(maxWidth: 200, alignment: .leading)
    }

    private func controls(_ actions: [CardAction]) -> some View {
        HStack(spacing: 3) {
            ForEach(actions) { action in
                Button(action.label, systemImage: action.symbol, action: action.perform)
                    .buttonStyle(PillControlStyle(isGo: action.isGo))
                    .help(action.label)
            }
        }
    }
}

/// What the pill shows, derived from the store and the clock at one moment.
private struct PillState {
    enum Kind {
        case live(tone: TimerTone, title: String, time: String)
        case onBreak(time: String, next: String)
        case waiting(title: String, time: String)
        case idle
    }

    var kind: Kind
    var progress: Double

    @MainActor init(store: BoardStore, clock: FocusClock?, at date: Date) {
        if let endsAt = store.breakEndsAtWallClock {
            let remaining = max(0, endsAt.timeIntervalSince(date))
            let next = store.focus.taskID.flatMap { id in store.tasks.first { $0.id == id }?.title } ?? "the next task"
            kind = .onBreak(time: TimerFormat.clock(Int(remaining.rounded(.up))), next: next)
            progress = store.focus.breakLength > 0 ? 1 - remaining / store.focus.breakLength : 1
        } else if let live = store.liveTask, let clock {
            let estimate = live.estimate ?? 3_600
            let elapsed = clock.elapsed(at: date)
            let tone = TimerTone(elapsed: elapsed, estimate: estimate, isRunning: clock.isRunning, inSprint: false)
            kind = .live(
                tone: tone, title: live.title, time: TimerFormat.remaining(estimate: estimate, elapsed: elapsed))
            progress = min(1, elapsed / estimate)
        } else if let next = store.nextScheduled {
            let parts = store.timeParts(for: next)
            kind = .waiting(title: next.title, time: "\(parts.time) \(parts.period)")
            progress = 0
        } else {
            kind = .idle
            progress = 0
        }
    }

    private var tone: TimerTone? {
        switch kind {
        case .live(let tone, _, _): tone
        case .onBreak: .onBreak
        case .waiting, .idle: nil
        }
    }

    var fill: Color {
        switch tone {
        case .timesUp: Palette.beamTimesUpBase.opacity(0.66)
        case .onBreak: Palette.beamBreakBase.opacity(0.62)
        case .paused: Color(white: 0.1).opacity(0.5)
        default: Color(white: 0.1).opacity(0.84)
        }
    }

    var edge: Color {
        switch tone {
        case .timesUp: Palette.danger.opacity(0.9)
        case .onBreak: Palette.green.opacity(0.5)
        default: Color.white.opacity(0.12)
        }
    }

    var edgeWidth: CGFloat { tone == .timesUp ? 1.5 : 1 }

    var line: [Color] {
        switch tone {
        case .timesUp: [Palette.danger, Palette.ember]
        case .onBreak: [Palette.green, Palette.mint]
        case .paused: [Palette.textDisabled, Palette.textMuted]
        default: [Palette.teal, Palette.lime]
        }
    }

    var glow: Color? {
        switch tone {
        case .live, .sprint: Palette.lime
        case .timesUp: Palette.danger
        case .onBreak: Palette.green
        case .paused, nil: nil
        }
    }

    var breathes: Bool { tone == .live || tone == .sprint }

    /// Hover controls (FloatingTimer ⑧): pause, done, skip, break, notes, expand while live; skip break and
    /// expand on a break; expand otherwise. Time's Up keeps its inline buttons instead.
    @MainActor func controls(store: BoardStore, notes: @escaping () -> Void) -> [CardAction] {
        let expand = CardAction(label: "Open the Focus Panel ⌘⇧T", symbol: "arrow.up.left.and.arrow.down.right") {
            store.toggleFloatingTimer()
        }
        switch kind {
        case .live(let tone, _, _) where tone == .timesUp:
            return []
        case .live(let tone, _, _):
            let paused = tone == .paused
            return [
                CardAction(label: paused ? "Resume ⌘⌥P" : "Pause ⌘⌥P", symbol: paused ? "play.fill" : "pause.fill") {
                    store.togglePause()
                },
                CardAction(label: "Done ⌘⌥F", symbol: "checkmark", isGo: true) { store.completeLive() },
                CardAction(label: "Skip ⌘⌥S", symbol: "forward.end") { store.skip() },
                CardAction(label: "Break ⌘⌥B", symbol: "cup.and.saucer") { store.takeBreak() },
                CardAction(label: "Notes ⌘⌥N", symbol: "note.text", perform: notes),
                expand,
            ]
        case .onBreak:
            return [CardAction(label: "Skip break", symbol: "play.fill") { store.endBreak() }, expand]
        case .waiting, .idle:
            return [expand]
        }
    }
}

/// `.ft-beam`: a 2 pt line inset 14 pt along the bottom edge, filled to the progress with a glowing head.
private struct ProgressLine: View {
    var progress: Double
    var fill: [Color]

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width * min(1, max(0, progress))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.07))
                Capsule()
                    .fill(LinearGradient(colors: fill, startPoint: .leading, endPoint: .trailing))
                    .frame(width: width)
                    .shadow(color: (fill.last ?? .clear).opacity(0.8), radius: 4)
                Circle()
                    .fill(.white)
                    .frame(width: 5, height: 5)
                    .shadow(color: (fill.last ?? .clear).opacity(0.9), radius: 4)
                    .offset(x: max(0, width - 2.5))
                    .opacity(progress > 0 ? 1 : 0)
            }
        }
        .frame(height: 2)
        .padding(.horizontal, 14)
        .offset(y: -1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// `.ft-c`: a 28 pt control that brightens on hover; the go variant lights lime.
private struct PillControlStyle: ButtonStyle {
    var isGo: Bool

    func makeBody(configuration: Configuration) -> some View {
        PillControlBody(configuration: configuration, isGo: isGo)
    }
}

private struct PillControlBody: View {
    var configuration: ButtonStyleConfiguration
    var isGo: Bool
    @State private var isHovered = false

    var body: some View {
        let lime = isGo && isHovered
        configuration.label
            .labelStyle(.iconOnly)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(lime ? Palette.onAccent : isHovered ? Palette.textPrimary : Palette.textBody)
            .frame(width: 28, height: 28)
            .background(
                lime ? Palette.lime : Color.white.opacity(isHovered ? 0.15 : 0),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .shadow(color: lime ? Palette.lime.opacity(0.85) : .clear, radius: 8)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.88 : isHovered ? 1.12 : 1)
            .animation(Motion.spring, value: configuration.isPressed)
            .animation(Motion.spring, value: isHovered)
            .onHover { isHovered = $0 }
    }
}

/// `.ft-tb`: Time's Up's inline `+5` (red) and `Done` (lime).
private struct PillTextButtonStyle: ButtonStyle {
    var isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Space.s2, style: .continuous)
        configuration.label
            .font(.system(size: 11.5, weight: .bold))
            .foregroundStyle(isPrimary ? Palette.onAccent : Palette.redText)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(isPrimary ? Palette.lime : Palette.danger.opacity(0.2), in: shape)
            .overlay(shape.strokeBorder(isPrimary ? .clear : Palette.dangerLine.opacity(0.35), lineWidth: 1))
            .shadow(color: isPrimary ? Palette.lime.opacity(0.8) : .clear, radius: 7)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(Motion.spring, value: configuration.isPressed)
    }
}

#Preview("Floating timer") {
    let running = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)
    let paused = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)
    paused.togglePause()
    let onBreak = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)
    onBreak.takeBreak()
    return VStack(spacing: 0) {
        FloatingTimerView(store: running)
        FloatingTimerView(store: paused)
        FloatingTimerView(store: onBreak)
    }
    .padding(Space.s6)
    .background(Palette.bg)
}
