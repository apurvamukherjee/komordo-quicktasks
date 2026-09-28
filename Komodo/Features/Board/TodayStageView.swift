import KomodoCore
import SwiftUI

/// Today on its own raised stage (DESIGN_SYSTEM §2.5, §13.2): gradient border, drifting aurora and an outer
/// glow around the day meter, the live task, the focus queue, quick add, Scheduled today and Done.
struct TodayStageView: View {
    var store: BoardStore
    var focusedTask: FocusState<String?>.Binding

    @State private var isDoneExpanded = false
    @State private var isTargeted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let borderWidth: CGFloat = 1.5

    var body: some View {
        // Start times, focused time and the day's end move with the clock, so re-derive them every half minute.
        TimelineView(.periodic(from: .now, by: 30)) { _ in stage }
    }

    private var stage: some View {
        let inner = RoundedRectangle(cornerRadius: Radius.stage - Self.borderWidth, style: .continuous)
        let layout = store.layout
        let plan = store.dayPlan()
        return VStack(spacing: 0) {
            header(openCount: layout.openToday.count)
            DayMeter(
                done: plan.done, total: plan.total, estimateLeft: plan.estimateLeft, focused: plan.focused,
                endsAround: store.startLabel(plan.endsAround)
            )
            .padding(.horizontal, Space.s4)
            .padding(.top, Space.s3)
            ScrollView {
                VStack(spacing: Space.s3) {
                    liveSection
                    if isEmpty(layout) {
                        emptyState
                    }
                    queueSection(plan: plan)
                    QuickAddField(store: store)
                    scheduledSection(layout.scheduledToday)
                    doneSection(layout.doneToday)
                }
                .padding(.horizontal, Space.s4)
                .padding(.top, 14)
                .padding(.bottom, Space.s4)
                .animation(reduceMotion ? nil : Motion.spring, value: store.focus)
            }
            .scrollIndicators(.never)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            ZStack(alignment: .top) {
                inner.fill(Palette.panel)
                Aurora()
                    .frame(height: 380)
                    .padding(.horizontal, -80)
                    .offset(y: -120)
            }
            .clipShape(inner)
        }
        .clipShape(inner)
        .overlay {
            if isTargeted { inner.strokeBorder(Palette.teal, style: StrokeStyle(lineWidth: 2, dash: [6, 4])) }
        }
        .spotlight(SpotlightTint.today, radius: Radius.stage - Self.borderWidth, lifts: false)
        .padding(Self.borderWidth)
        .background {
            RoundedRectangle(cornerRadius: Radius.stage, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Palette.teal.opacity(0.75), location: 0),
                            .init(color: Palette.lime.opacity(0.45), location: 0.3),
                            .init(color: .white.opacity(0.06), location: 0.6),
                            .init(color: Palette.lime.opacity(0.25), location: 1),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: Palette.lime.opacity(0.3), radius: 40)
        }
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            store.move(id, to: .today)
            return true
        } isTargeted: {
            isTargeted = $0
        }
    }

    private func header(openCount: Int) -> some View {
        HStack(spacing: Space.s3) {
            Image(systemName: "sun.max")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.onAccent)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(
                        colors: [Palette.teal, Palette.lime], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .shadow(color: Palette.lime.opacity(0.6), radius: 10, y: 6)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Space.s2) {
                    Text("Today")
                        .font(.system(size: 18, weight: .heavy))
                        .tracking(-0.36)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize()
                    CountBadge(count: openCount, tint: Palette.lime, textColor: Palette.limeText)
                    if store.isFocusing {
                        HStack(spacing: 5) {
                            Circle().fill(Palette.lime).frame(width: 5, height: 5).ping(Palette.lime)
                            Text("FOCUS MODE")
                        }
                        .font(.system(size: 10, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(Palette.limeText)
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background(Palette.lime.opacity(0.1), in: Capsule())
                        .fixedSize()
                    }
                }
                Text("Focus queue · runs top to bottom")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textMuted)
                    .lineLimit(1)
            }
            .layoutPriority(1)
            Spacer(minLength: 0)
            KeyCap("⌘⇧B")
        }
        .padding(.leading, Space.s5)
        .padding(.trailing, 18)
        .padding(.top, Space.s5)
        .padding(.bottom, 6)
    }

    @ViewBuilder private var liveSection: some View {
        if let endsAt = store.breakEndsAtWallClock {
            BreakCard(
                endsAt: endsAt,
                upNext: store.focus.taskID.flatMap { id in store.tasks.first { $0.id == id }?.title }
                    ?? "the next task",
                onSkip: store.endBreak, onAddTwoMinutes: { store.extendBreak(by: 120) }
            )
            .transition(.rise(reduceMotion: reduceMotion))
        } else if let live = store.liveTask {
            LiveTaskCard(model: store.liveModel(for: live), clock: store.focusClock(for: live), actions: controlActions)
                .id(live.id)
                .transition(.rise(reduceMotion: reduceMotion))
        } else if store.focus.isDayWon {
            WonDayCard(plan: store.dayPlan())
                .transition(.rise(reduceMotion: reduceMotion))
        }
    }

    private var controlActions: ControlBarActions {
        ControlBarActions(
            takeBreak: store.takeBreak, openNotes: { store.inspect(store.focus.taskID) },
            togglePause: store.togglePause, skip: store.skip,
            done: store.completeLive, addFive: { store.extendEstimate(by: 300) },
            addFifteen: { store.extendEstimate(by: 900) }, next: store.skip)
    }

    @ViewBuilder private func queueSection(plan: DayPlan) -> some View {
        let queue = store.queue
        if !queue.isEmpty {
            SectionHeader("UP NEXT", detail: "hover a card · bolt makes it live")
            let firstPosition = store.liveTask == nil ? 1 : 2
            ForEach(Array(queue.enumerated()), id: \.element.id) { index, task in
                QueueCard(
                    model: store.cardModel(for: task), position: firstPosition + index,
                    startsAt: plan.startTimes.indices.contains(index) ? store.startLabel(plan.startTimes[index]) : "—",
                    onDone: { store.toggleDone(task.id) }, onMakeLive: { store.makeLive(task.id) },
                    isFocused: focusedTask.wrappedValue == task.id
                )
                .boardCardBehavior(store: store, task: task, focusedTask: focusedTask, onAdd: {})
                .transition(.rise(reduceMotion: reduceMotion))
            }
        }
    }

    @ViewBuilder private func scheduledSection(_ scheduled: [TaskItem]) -> some View {
        if !scheduled.isEmpty {
            SectionHeader("SCHEDULED TODAY", symbol: "calendar", detail: "\(scheduled.count)")
            ForEach(scheduled) { task in
                ScheduledTaskCard(store: store, task: task)
                    .boardCardBehavior(store: store, task: task, focusedTask: focusedTask, onAdd: {})
            }
        }
    }

    @ViewBuilder private func doneSection(_ done: [TaskItem]) -> some View {
        if !done.isEmpty {
            let taken = done.reduce(0) { $0 + $1.timeTaken(at: store.now) }
            DoneSectionButton(
                summary: "\(done.count) Done · \(DurationFormat.short(taken))", isExpanded: $isDoneExpanded)
            if isDoneExpanded {
                ForEach(done) { task in
                    TaskCard(model: store.cardModel(for: task), column: .today)
                        .boardCardBehavior(store: store, task: task, focusedTask: focusedTask, onAdd: {})
                        .transition(.opacity)
                }
            }
        }
    }

    private func isEmpty(_ layout: BoardLayout) -> Bool {
        layout.openToday.isEmpty && store.liveTask == nil && store.focus.breakEndsAt == nil && !store.focus.isDayWon
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing planned", systemImage: "sun.max")
        } description: {
            Text("Nothing planned. Pull something in from This week, or add a task.")
        }
        .foregroundStyle(Palette.textSecondary)
        .padding(.vertical, Space.s6)
    }
}

/// Always-open quick add at the foot of the queue: a trailing estimate or a preset sets the EST, Return adds,
/// ⌘↵ adds and makes it live.
private struct QuickAddField: View {
    var store: BoardStore

    @State private var title = ""
    @State private var preset: TimeInterval?
    @FocusState private var isFocused: Bool

    private static let presets: [(String, TimeInterval)] = [("15m", 900), ("30m", 1_800), ("1h", 3_600)]

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Space.s4, style: .continuous)
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: Space.s2) {
                Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundStyle(Palette.textMuted)
                TextField(
                    "Add a task",
                    text: $title,
                    prompt: Text("Add a task… try “Write spec 45m”").foregroundStyle(Palette.textMuted)
                )
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Palette.textPrimary)
                .focused($isFocused)
                .focusEffectDisabled()
                .onSubmit { add(andStart: false) }
                KeyCap("↵")
            }
            HStack(spacing: 6) {
                ForEach(Self.presets, id: \.0) { label, seconds in
                    Button(label) { preset = preset == seconds ? nil : seconds }
                        .buttonStyle(.presetChip)
                        .overlay {
                            if preset == seconds {
                                RoundedRectangle(cornerRadius: 7).strokeBorder(Palette.lime.opacity(0.6))
                            }
                        }
                }
                Spacer()
                Text("⌘↵ add & start").font(.system(size: 11)).foregroundStyle(Palette.textMuted)
                Button("Add and start") { add(andStart: true) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .hidden()
                    .frame(width: 0, height: 0)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .background(isFocused ? Palette.card : Color.white.opacity(0.04), in: shape)
        .overlay(shape.strokeBorder(isFocused ? Palette.teal.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1))
        .background(shape.stroke(isFocused ? Palette.teal.opacity(0.12) : .clear, lineWidth: 8))
        .animation(Motion.fast, value: isFocused)
    }

    private func add(andStart: Bool) {
        guard let task = store.addTask(title, to: .today, estimate: preset) else { return }
        title = ""
        preset = nil
        if andStart { store.makeLive(task.id) }
    }
}

/// A task with a time today: the time on the left over a fading blue line, then the title and chips.
private struct ScheduledTaskCard: View {
    var store: BoardStore
    var task: TaskItem

    var body: some View {
        let parts = store.timeParts(for: task)
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 3) {
                Text(parts.time)
                    .font(.system(size: 15, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Palette.blueText)
                Text(parts.period)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.textMuted)
                LinearGradient(colors: [Palette.blue, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(width: 2)
                    .clipShape(Capsule())
            }
            .frame(width: 46)
            VStack(alignment: .leading, spacing: 9) {
                Text(task.title)
                    .font(Typography.cardTitle)
                    .lineSpacing(3)
                    .foregroundStyle(Palette.textPrimary)
                FlowLayout {
                    if task.source == .calendar { Chip("Calendar", tint: .blue, icon: "calendar") }
                    if let estimate = task.estimate { Chip(DurationFormat.short(estimate)) }
                    Chip("Reminder on", icon: "bell")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, Space.s4)
        .spotlight(SpotlightTint.week) { CardSurface() }
    }
}

/// The end of the queue: "You won the day." with tasks done, time focused, and how close the estimates were.
private struct WonDayCard: View {
    var plan: DayPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("You won the day.")
                .font(.system(size: 24, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Palette.textPrimary)
            WeightedHStack(weights: [1, 1], spacing: Space.s2) {
                stat("\(plan.done)", "tasks")
                stat(DurationFormat.short(plan.focused), "focused")
            }
        }
        .padding(.vertical, Space.s5)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Palette.panel
                EllipticalGradient(
                    colors: [Palette.amber.opacity(0.14), .clear], center: .top, startRadiusFraction: 0,
                    endRadiusFraction: 0.9)
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
        .spotlight(SpotlightTint.today, radius: 24, lifts: false)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 24, weight: .heavy).monospacedDigit()).foregroundStyle(Palette.textPrimary)
            Text(label).font(.system(size: 11)).foregroundStyle(Palette.textSecondary)
        }
        .padding(Space.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
    }
}

#Preview("Today stage") {
    struct Demo: View {
        @State private var store = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)
        @FocusState private var focused: String?

        var body: some View {
            TodayStageView(store: store, focusedTask: $focused)
                .frame(width: 470, height: 900)
                .padding(Space.s5)
                .background(Palette.bg)
        }
    }
    return Demo()
}
