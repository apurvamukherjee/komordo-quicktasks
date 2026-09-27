import KomodoCore
import SwiftUI

/// Backlog or This week: a tinted column with its header, cards in priority order, and **+ ADD TASK**.
/// Cards drag within and across columns; a drop on a card lands before it, a drop on the column at the end.
struct BoardColumnView: View {
    enum AddPosition {
        case top
        case bottom
    }

    var store: BoardStore
    var bucket: Bucket
    var focusedTask: FocusState<String?>.Binding

    @State private var adding: AddPosition?
    @State private var isTargeted = false

    private var tone: ColumnTone { bucket == .week ? .week : .backlog }
    private var tasks: [TaskItem] { bucket == .week ? store.layout.week : store.layout.backlog }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.column, style: .continuous)
        VStack(spacing: 0) {
            ColumnHeader(
                symbol: bucket == .week ? "calendar" : "moon", title: BoardStore.title(for: bucket),
                subtitle: subtitle, count: tasks.count, tone: tone
            ) {
                adding = .top
            }
            if bucket == .week {
                WeekStrip(store: store)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
            }
            ScrollView {
                VStack(spacing: Space.s3) {
                    if adding == .top { addField(atTop: true) }
                    ForEach(tasks) { task in
                        BoardCard(
                            store: store, task: task, bucket: bucket, focusedTask: focusedTask,
                            onAdd: { adding = .bottom })
                    }
                    if adding == .bottom {
                        addField(atTop: false)
                    } else {
                        AddTaskButton(column: tone) { adding = .bottom }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, Space.s3)
                .padding(.bottom, 14)
            }
            .scrollIndicators(.never)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { ColumnBackground(tone: tone, shape: shape) }
        .clipShape(shape)
        .overlay {
            if isTargeted {
                shape.strokeBorder(Palette.teal, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
        }
        .spotlight(tone.spotlight, radius: Radius.column, lifts: false)
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first else { return false }
            store.move(id, to: bucket)
            return true
        } isTargeted: {
            isTargeted = $0
        }
    }

    private var subtitle: String {
        let total = DurationFormat.short(tasks.reduce(0) { $0 + ($1.estimate ?? 0) })
        guard bucket == .week else { return "Someday · \(total) parked" }
        let start = store.week.start.startOfDay(in: store.calendar)
        let end = store.week.end.startOfDay(in: store.calendar)
        return
            "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.day())) · \(total) planned"
    }

    private func addField(atTop: Bool) -> some View {
        InlineAddField { title in
            store.addTask(title, to: bucket, atTop: atTop)
            adding = nil
        } onCancel: {
            adding = nil
        }
    }
}

/// A task card on the Board with its column's actions, drag and drop, keyboard and context menu.
struct BoardCard: View {
    var store: BoardStore
    var task: TaskItem
    var bucket: Bucket
    var focusedTask: FocusState<String?>.Binding
    var onAdd: () -> Void

    var body: some View {
        TaskCard(
            model: store.cardModel(for: task), column: bucket == .week ? .week : .backlog,
            subtaskDisplay: bucket == .week ? .ring : .chip, actions: actions,
            isFocused: focusedTask.wrappedValue == task.id
        )
        .boardCardBehavior(store: store, task: task, focusedTask: focusedTask, onAdd: onAdd)
    }

    private var actions: [CardAction] {
        switch bucket {
        case .backlog:
            [
                CardAction(label: "Move to This week", symbol: "arrow.right") { store.move(task.id, to: .week) },
                CardAction(label: "Mark done", symbol: "checkmark") { store.toggleDone(task.id) },
            ]
        case .week, .today:
            [
                CardAction(label: "Mark done", symbol: "checkmark") { store.toggleDone(task.id) },
                CardAction(label: "Move to Today", symbol: "arrow.right") { store.move(task.id, to: .today) },
            ]
        }
    }
}

extension View {
    /// What every card on the Board does besides looking right: a click opens it in the inspector, it drags,
    /// accepts drops before itself, takes keyboard focus (Space toggles done, ⌥↑/⌥↓ move, N adds), and has the card menu.
    func boardCardBehavior(
        store: BoardStore, task: TaskItem, focusedTask: FocusState<String?>.Binding, onAdd: @escaping () -> Void
    ) -> some View {
        let column = task.column(in: store.week)
        return
            self
            .focusable()
            .focused(focusedTask, equals: task.id)
            .focusEffectDisabled()
            .onTapGesture {
                focusedTask.wrappedValue = task.id
                store.inspect(task.id)
            }
            .onKeyPress(.space) {
                store.toggleDone(task.id)
                return .handled
            }
            .onKeyPress(keys: [.upArrow, .downArrow]) { press in
                guard press.modifiers.contains(.option) else { return .ignored }
                store.nudge(task.id, by: press.key == .upArrow ? -1 : 1)
                return .handled
            }
            .onKeyPress("n") {
                onAdd()
                return .handled
            }
            .draggable(task.id) {
                Text(task.title)
                    .font(Typography.cardTitle)
                    .foregroundStyle(Palette.textPrimary)
                    .padding(Space.s4)
                    .background(Palette.raised, in: RoundedRectangle(cornerRadius: Radius.card))
            }
            .dropDestination(for: String.self) { ids, _ in
                guard let id = ids.first else { return false }
                store.move(id, to: column, before: task.id)
                return true
            }
            .contextMenu {
                if column == .today && !task.isDone {
                    Button("Make live", systemImage: "bolt.fill") { store.makeLive(task.id) }
                }
                Button(task.isDone ? "Mark not done" : "Mark done", systemImage: "checkmark") {
                    store.toggleDone(task.id)
                }
                Divider()
                ForEach(Bucket.allCases.filter { $0 != column }, id: \.self) { bucket in
                    Button("Move to \(BoardStore.title(for: bucket))") { store.move(task.id, to: bucket) }
                }
            }
    }
}

/// The column's name, count and summary, with **+** to insert at the top.
struct ColumnHeader: View {
    var symbol: String
    var title: String
    var subtitle: String
    var count: Int
    var tone: ColumnTone
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: Space.s3) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tone == .week ? Palette.blueText : Palette.violetText)
                .frame(width: 36, height: 36)
                .background(tone.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tone.accent.opacity(0.34), lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Space.s2) {
                    Text(title).font(Typography.heading).tracking(-0.16).foregroundStyle(Palette.textPrimary)
                    CountBadge(
                        count: count, tint: tone.accent,
                        textColor: tone == .week ? Palette.blueText : Palette.violetText)
                }
                Text(subtitle).font(.system(size: 12)).foregroundStyle(Palette.textMuted).lineLimit(1)
            }
            Spacer(minLength: 0)
            Button("Add task to the top of \(title)", systemImage: "plus", action: onAdd)
                .buttonStyle(.cardAction)
                .help("Add to the top")
        }
        .padding(.leading, 18)
        .padding(.trailing, Space.s4)
        .padding(.top, Space.s5)
        .padding(.bottom, Space.s2)
    }
}

/// The column's material: panel fill, the tone's ambient wash from the top, a 3 pt top bar and a hairline.
private struct ColumnBackground: View {
    var tone: ColumnTone
    var shape: RoundedRectangle

    var body: some View {
        ZStack(alignment: .top) {
            shape.fill(Palette.panel)
            EllipticalGradient(
                colors: [tone.accent.opacity(tone == .week ? 0.2 : 0.18), .clear],
                center: UnitPoint(x: 0.5, y: -0.3), startRadiusFraction: 0, endRadiusFraction: 0.7
            )
            .frame(height: 240)
            LinearGradient(colors: barColors, startPoint: .leading, endPoint: .trailing)
                .frame(height: 3)
                .opacity(tone == .backlog ? 0.8 : 1)
            shape.strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        }
    }

    private var barColors: [Color] {
        tone == .week
            ? [.clear, Palette.blue, Palette.cyan, .clear] : [.clear, Palette.violet, Palette.violet, .clear]
    }
}

/// Seven days with a load bar each; today ringed lime, the rest of the week tinted blue (DESIGN_SYSTEM §2.5).
struct WeekStrip: View {
    var store: BoardStore

    var body: some View {
        let loads = dayLoads
        let peak = max(loads.max() ?? 1, 1)
        HStack(spacing: 3) {
            ForEach(Array(store.week.days.enumerated()), id: \.offset) { index, day in
                WeekDayCell(
                    day: day, isToday: day == store.today, isAhead: day > store.today, load: loads[index] / peak,
                    calendar: store.calendar)
            }
        }
        .padding(6)
        .background(Palette.blue.opacity(0.05), in: RoundedRectangle(cornerRadius: Space.s4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Space.s4, style: .continuous)
                .strokeBorder(Palette.blue.opacity(0.12), lineWidth: 1))
    }

    /// Planned time per day: what's scheduled on it, plus Today's column for today and focused time for days
    /// already past.
    private var dayLoads: [TimeInterval] {
        let focused = FocusHistory.daily(store.tasks, days: store.week.days, now: store.now, calendar: store.calendar)
        return store.week.days.enumerated().map { index, day in
            if day < store.today { return focused[index] }
            let scheduled = store.tasks.filter { $0.scheduledDate == day && !$0.isDone }
                .reduce(0) { $0 + ($1.estimate ?? 0) }
            let today = day == store.today ? store.layout.upNext.reduce(0) { $0 + ($1.estimate ?? 0) } : 0
            return scheduled + today
        }
    }
}

private struct WeekDayCell: View {
    var day: LocalDate
    var isToday: Bool
    var isAhead: Bool
    var load: Double
    var calendar: Calendar

    @State private var isHovered = false

    var body: some View {
        let date = day.startOfDay(in: calendar)
        VStack(spacing: 5) {
            Text(String(date.formatted(.dateTime.weekday(.narrow))))
                .font(.system(size: 10, weight: isToday ? .bold : .semibold))
                .foregroundStyle(isToday ? Palette.limeText : isAhead ? Palette.blueText : Palette.textMuted)
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: 13, weight: isToday ? .heavy : .semibold).monospacedDigit())
                .foregroundStyle(isToday ? Palette.textPrimary : isAhead ? Palette.textBody : Palette.textMuted)
            Capsule()
                .fill(barStyle)
                .frame(width: 8 + 12 * min(1, max(0, load)), height: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.s2)
        .background(background, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            if isToday {
                RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Palette.lime.opacity(0.4))
            }
        }
        .offset(y: isHovered ? -2 : 0)
        .animation(Motion.spring, value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
    }

    private var barStyle: AnyShapeStyle {
        if isToday { return AnyShapeStyle(Palette.liveGradient) }
        return AnyShapeStyle(isAhead ? Palette.blue : Color.white.opacity(0.14))
    }

    private var background: AnyShapeStyle {
        if isToday {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Palette.teal.opacity(0.2), Palette.lime.opacity(0.08)], startPoint: .top,
                    endPoint: .bottom))
        }
        if isHovered { return AnyShapeStyle(Palette.blue.opacity(0.14)) }
        return AnyShapeStyle(isAhead ? Palette.blue.opacity(0.1) : Color.clear)
    }
}

/// Inline title entry for a new task; a trailing estimate like `45m` becomes its EST.
struct InlineAddField: View {
    var onSubmit: (String) -> Void
    var onCancel: () -> Void

    @State private var title = ""

    var body: some View {
        KomodoTextField("New task — try “Write spec 45m”", text: $title, focusesOnAppear: true)
            .onSubmit {
                let trimmed = title.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { onCancel() } else { onSubmit(trimmed) }
            }
            .onExitCommand(perform: onCancel)
    }
}

#Preview("Columns") {
    struct Demo: View {
        @State private var store = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)
        @FocusState private var focused: String?

        var body: some View {
            HStack(alignment: .top, spacing: Space.columnGutter) {
                BoardColumnView(store: store, bucket: .backlog, focusedTask: $focused)
                BoardColumnView(store: store, bucket: .week, focusedTask: $focused)
            }
            .frame(width: 680, height: 820)
            .padding(Space.s5)
            .background(Palette.bg)
        }
    }
    return Demo()
}
