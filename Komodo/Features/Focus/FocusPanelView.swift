import KomodoCore
import SwiftUI

/// The Focus Panel (DESIGN_SYSTEM §13.8, FEATURES §4.8): the header, the day at a glance, the live task or
/// whatever stands in for it, then the editable queue, Scheduled today and Done. It reads the same store as
/// the Board, so both show one timer.
struct FocusPanelView: View {
    @Bindable var store: BoardStore

    @State private var isAdding = false
    @State private var isScheduledExpanded = true
    @State private var isDoneExpanded = false
    @State private var isShowingSettings = false
    @State private var isShowingNotes = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Est left and the start times move with the clock, so re-derive them every half minute.
        TimelineView(.periodic(from: .now, by: 30)) { _ in panel }
            .frame(width: Layout.focusPanelWidth)
            .frame(maxHeight: .infinity, alignment: .top)
            .background { FocusPanelBackground(side: store.panelSide) }
            .preferredColorScheme(.dark)
    }

    private var panel: some View {
        let plan = store.dayPlan()
        return VStack(spacing: 0) {
            header
            daySummary(plan)
                .padding(.horizontal, 14)
                .padding(.top, 2)
            if store.focus.isDayWon {
                ScrollView { wonList(plan) }.scrollIndicators(.never)
            } else {
                hero
                    .padding(.horizontal, 14)
                    .padding(.top, Space.s3)
                ScrollView { list }.scrollIndicators(.never)
            }
        }
        .animation(reduceMotion ? nil : Motion.spring, value: store.focus)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: Space.s2) {
            listPicker
            Text("Today")
                .font(.system(size: 17, weight: .heavy))
                .tracking(-0.34)
                .foregroundStyle(Palette.textPrimary)
                .padding(.leading, 2)
            FocusModeChip(store: store)
            Spacer(minLength: 0)
            Button("Quick Settings", systemImage: "gearshape") { isShowingSettings.toggle() }
                .buttonStyle(.icon(isToggled: isShowingSettings))
                .help("Quick Settings")
                .popover(isPresented: $isShowingSettings, arrowEdge: .bottom) {
                    QuickSettingsView(store: store)
                }
            Button("Exit Focus mode", systemImage: "house", action: store.exitFocusPanel)
                .buttonStyle(.icon())
                .help("Exit Focus mode (Home)")
            Button("Collapse to floating timer", systemImage: "pip.enter") {}
                .buttonStyle(.icon())
                .disabled(true)
                .help("The floating timer arrives in the next milestone")
        }
        .padding(.leading, 14)
        .padding(.trailing, Space.s3)
        .padding(.top, 10)
        .frame(height: 52)
    }

    /// "All ▾": which lists feed the Focus queue. It's the Board's list filter, so both stay in step.
    private var listPicker: some View {
        let shape = RoundedRectangle(cornerRadius: Space.s2, style: .continuous)
        return Menu {
            Button("All lists") { store.showList(nil) }
            Divider()
            ForEach(store.lists) { list in
                Button(list.name) { store.showList(list.id) }
            }
        } label: {
            HStack(spacing: 6) {
                Text(store.selectedList?.name ?? "All").lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Palette.textMuted)
            }
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(Palette.textPrimary)
            .padding(.leading, 10)
            .padding(.trailing, Space.s2)
            .frame(height: 28)
            .background(Color.white.opacity(0.05), in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
            .contentShape(shape)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Choose which lists feed the Focus queue")
    }

    // MARK: Day

    private func daySummary(_ plan: DayPlan) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    (Text("\(plan.done)")
                        + Text("/\(plan.total)").fontWeight(.semibold).foregroundColor(Palette.textMuted))
                        .font(.system(size: 22, weight: .heavy).monospacedDigit())
                        .tracking(-0.66)
                        .foregroundStyle(Palette.textPrimary)
                    Text("DONE")
                        .font(.system(size: 10.5, weight: .heavy))
                        .tracking(0.84)
                        .foregroundStyle(Palette.limeText)
                }
                Spacer()
                (Text("Est left ")
                    + Text(DurationFormat.short(plan.estimateLeft)).bold().foregroundColor(Palette.textPrimary))
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(Palette.textSecondary)
            }
            HStack(spacing: 4) {
                ForEach(0..<max(plan.total, 1), id: \.self) { index in
                    DaySegment(state: segmentState(index, plan: plan), height: 6)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, Space.s3)
        .padding(.bottom, 13)
        .spotlight(SpotlightTint.today, radius: Space.s4, lifts: false) { TileSurface(radius: Space.s4) }
        .accessibilityElement(children: .combine)
    }

    private func segmentState(_ index: Int, plan: DayPlan) -> DaySegment.State {
        if index < plan.done { return .done }
        guard index == plan.done, plan.done < plan.total, !store.focus.isDayWon else { return .upcoming }
        return store.nextScheduled == nil ? .current : .waiting
    }

    // MARK: Live

    @ViewBuilder private var hero: some View {
        if let endsAt = store.breakEndsAtWallClock {
            FocusBreakCard(
                endsAt: endsAt, length: store.focus.breakLength,
                upNext: store.focus.taskID.flatMap { id in store.tasks.first { $0.id == id }?.title }
                    ?? "the next task",
                onSkip: store.endBreak, onAddTwoMinutes: { store.extendBreak(by: 120) }
            )
            .transition(.rise(reduceMotion: reduceMotion))
        } else if let live = store.liveTask {
            FocusHeroCard(model: store.liveModel(for: live), clock: store.focusClock(for: live), actions: controls)
                .id(live.id)
                .transition(.rise(reduceMotion: reduceMotion))
                .popover(isPresented: $isShowingNotes, arrowEdge: store.panelSide == .right ? .leading : .trailing) {
                    InspectorNotes(store: store, task: live)
                        .frame(width: Layout.inspectorMin)
                        .padding(Space.s3)
                }
        } else if let next = store.nextScheduled {
            let parts = store.timeParts(for: next)
            FocusScheduledCard(title: next.title, time: "\(parts.time) \(parts.period)") {
                store.makeLive(next.id)
            }
            .transition(.rise(reduceMotion: reduceMotion))
        }
    }

    /// Notes opens in a popover beside the panel, because the inspector lives in the hidden Home window.
    private var controls: ControlBarActions {
        ControlBarActions(
            takeBreak: store.takeBreak, openNotes: { isShowingNotes = true }, togglePause: store.togglePause,
            skip: store.skip, done: store.completeLive, addFive: { store.extendEstimate(by: 300) },
            addFifteen: { store.extendEstimate(by: 900) }, next: store.skip)
    }

    // MARK: Lists

    private var list: some View {
        let layout = store.layout
        let queue = store.queue
        let scheduled = layout.scheduledToday.filter { $0.id != store.focus.taskID }
        return VStack(spacing: 7) {
            if !queue.isEmpty {
                HStack {
                    Text("UP NEXT").font(Typography.label).tracking(Typography.Tracking.label)
                        .foregroundStyle(Palette.textSecondary)
                    Spacer()
                    Text("hover · bolt makes it live").font(.system(size: 11)).foregroundStyle(Palette.textMuted)
                }
                .padding(.horizontal, 2)
                .padding(.bottom, 2)
                let first = store.liveTask == nil ? 1 : 2
                ForEach(Array(queue.enumerated()), id: \.element.id) { index, task in
                    FocusQueueRow(
                        model: store.cardModel(for: task), position: first + index,
                        onDone: { store.toggleDone(task.id) }, onMakeLive: { store.makeLive(task.id) }
                    )
                    .contextMenu { rowMenu(task) }
                    .transition(.rise(reduceMotion: reduceMotion))
                }
            }
            if isAdding {
                InlineAddField { title in
                    store.addTask(title, to: .today)
                    isAdding = false
                } onCancel: {
                    isAdding = false
                }
            } else {
                FocusAddTaskButton { isAdding = true }
            }
            if !scheduled.isEmpty {
                scheduledHeader(count: scheduled.count)
                if isScheduledExpanded {
                    ForEach(scheduled) { task in
                        scheduledRow(task).contextMenu { rowMenu(task) }
                    }
                }
            }
            doneSection(layout.doneToday).padding(.top, 2)
        }
        .padding(.horizontal, 14)
        .padding(.top, Space.s3)
        .padding(.bottom, 14)
    }

    private func scheduledHeader(count: Int) -> some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(Motion.base) { isScheduledExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(isScheduledExpanded ? 0 : -90))
                        .foregroundStyle(Palette.textSecondary)
                    Text("SCHEDULED TODAY").font(Typography.label).tracking(Typography.Tracking.label)
                        .foregroundStyle(Palette.textSecondary)
                    Text("\(count)").font(.system(size: 11).monospacedDigit()).foregroundStyle(Palette.textMuted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(isScheduledExpanded ? "Expanded" : "Collapsed")
            Spacer()
            Button("Add scheduled task", systemImage: "plus") {}
                .buttonStyle(.icon(.compact))
                .disabled(true)
                .help("Schedule tasks from the Board for now")
        }
        .padding(.horizontal, 2)
        .padding(.top, 6)
    }

    private func scheduledRow(_ task: TaskItem) -> some View {
        let parts = store.timeParts(for: task)
        let detail = [
            task.estimate.map(DurationFormat.short), task.remindsAtStart ? "Reminder on" : nil,
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
        return FocusScheduledRow(
            time: parts.time, period: parts.period, title: task.title, detail: detail,
            fromCalendar: task.source == .calendar)
    }

    @ViewBuilder private func doneSection(_ done: [TaskItem]) -> some View {
        if !done.isEmpty {
            let taken = done.reduce(0) { $0 + $1.timeTaken(at: store.now) }
            DoneSectionButton(
                summary: "\(done.count) Done · \(DurationFormat.short(taken))", isExpanded: $isDoneExpanded)
            if isDoneExpanded {
                ForEach(done) { task in
                    TaskCard(model: store.cardModel(for: task), column: .today)
                        .contextMenu { rowMenu(task) }
                        .transition(.opacity)
                }
            }
        }
    }

    /// Every list action works here too (DESIGN_SYSTEM §13.8), apart from the ones that open the Home window.
    @ViewBuilder private func rowMenu(_ task: TaskItem) -> some View {
        if !task.isDone {
            Button("Make live", systemImage: "bolt.fill") { store.makeLive(task.id) }
        }
        Button(task.isDone ? "Mark not done" : "Mark done", systemImage: "checkmark") { store.toggleDone(task.id) }
        Divider()
        Button("Duplicate", systemImage: "plus.square.on.square") { store.duplicate(task.id) }
        Button("Delete", systemImage: "trash", role: .destructive) { store.delete(task.id) }
    }

    private func wonList(_ plan: DayPlan) -> some View {
        VStack(spacing: 10) {
            FocusWonCard(
                date: store.now, done: plan.done, focused: plan.focused,
                summary: DaySummary(doneToday: store.layout.doneToday, now: store.now),
                onDone: store.closeDaySummary
            )
            .transition(.rise(reduceMotion: reduceMotion))
            doneSection(store.layout.doneToday)
        }
        .padding(.horizontal, 14)
        .padding(.top, Space.s3)
        .padding(.bottom, Space.s4)
    }
}

/// The FOCUS pill beside the title, colored by what the timer is doing. It pings while time moves and checks
/// each second for Time's Up, which only the clock knows.
private struct FocusModeChip: View {
    var store: BoardStore

    var body: some View {
        let clock = store.liveTask.map { store.focusClock(for: $0) }
        TimelineView(.periodic(from: .now, by: clock?.isRunning == true ? 1 : 3600)) { context in
            chip(at: context.date, clock: clock)
        }
    }

    private func chip(at date: Date, clock: FocusClock?) -> some View {
        let onBreak = store.breakEndsAtWallClock != nil
        let isRunning = clock?.isRunning ?? false
        let timesUp = clock.map { $0.elapsed(at: date) > (store.liveTask?.estimate ?? .infinity) } ?? false
        let (text, fill): (Color, Color) =
            if onBreak { (Palette.greenText, Palette.green.opacity(0.12)) } else if timesUp {
                (Palette.redText, Palette.danger.opacity(0.14))
            } else if isRunning { (Palette.limeText, Palette.lime.opacity(0.1)) } else {
                (Palette.textSecondary, Color.white.opacity(0.06))
            }
        return HStack(spacing: 5) {
            if isRunning || onBreak {
                Circle().fill(text).frame(width: 5, height: 5).ping(text)
            } else {
                Circle().fill(text).frame(width: 5, height: 5)
            }
            Text("FOCUS")
        }
        .font(.system(size: 9.5, weight: .heavy))
        .tracking(0.76)
        .foregroundStyle(text)
        .padding(.horizontal, 7)
        .frame(height: 20)
        .background(fill, in: Capsule())
        .fixedSize()
    }
}

/// `.fp-panel`: a teal wash at the top and a faint lime one down the side over a dark fall-off, rounded on the
/// edge that faces the screen.
private struct FocusPanelBackground: View {
    var side: BoardStore.PanelSide

    var body: some View {
        let radius: CGFloat = 20
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: side == .right ? radius : 0, bottomLeadingRadius: side == .right ? radius : 0,
            bottomTrailingRadius: side == .left ? radius : 0, topTrailingRadius: side == .left ? radius : 0,
            style: .continuous)
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Palette.card, location: 0), .init(color: Palette.panel, location: 0.42),
                    .init(color: Palette.bg, location: 1),
                ], startPoint: .top, endPoint: .bottom)
            EllipticalGradient(
                colors: [Palette.teal.opacity(0.09), .clear], center: UnitPoint(x: 0.5, y: -0.04),
                startRadiusFraction: 0, endRadiusFraction: 0.7
            )
            .frame(height: 560)
            .frame(maxHeight: .infinity, alignment: .top)
            EllipticalGradient(
                colors: [Palette.lime.opacity(0.05), .clear], center: UnitPoint(x: side == .right ? 1 : 0, y: 0.42),
                startRadiusFraction: 0, endRadiusFraction: 0.7)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

#Preview("Focus Panel") {
    FocusPanelView(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
        .frame(height: 960)
        .background(Palette.bg)
}
