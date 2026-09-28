import KomodoCore
import SwiftUI

/// Card menu → Schedule (DESIGN_SYSTEM §13.6, FEATURES §4.6). Step 1 picks a day from the quick rows or the
/// calendar; step 2 adds an optional time, a repeat rule and the reminder, then saves.
struct SchedulePopover: View {
    enum Step {
        case date
        case details
    }

    var store: BoardStore
    var task: TaskItem
    var dismiss: () -> Void

    @State private var step = Step.date
    @State private var draft: BoardStore.Schedule
    @State private var isCustomizing = false
    private let original: BoardStore.Schedule

    init(store: BoardStore, task: TaskItem, dismiss: @escaping () -> Void) {
        self.store = store
        self.task = task
        self.dismiss = dismiss
        let schedule = store.schedule(for: task)
        original = schedule
        _draft = State(initialValue: schedule)
        // A task that already has a day opens on its details, as the canvas's "editing a repeat" does.
        _step = State(initialValue: task.scheduledDate == nil && schedule.rule == nil ? .date : .details)
        _isCustomizing = State(initialValue: LaunchOptions.opensCustomRepeat)
    }

    var body: some View {
        Group {
            switch step {
            case .date: ScheduleDateStep(store: store, draft: $draft) { step = .details }
            case .details:
                ScheduleDetailsStep(
                    store: store, draft: $draft, original: original,
                    canRemove: task.scheduledDate != nil || original.rule != nil, back: { step = .date },
                    customize: { isCustomizing = true },
                    remove: {
                        store.removeSchedule(task.id)
                        dismiss()
                    },
                    save: {
                        store.setSchedule(task.id, to: draft)
                        dismiss()
                    })
            }
        }
        .frame(width: 320)
        .background(Palette.raised)
        .sheet(isPresented: $isCustomizing) {
            CustomRepeatSheet(
                title: task.title, start: draft.date, rule: draft.rule, calendar: store.calendar,
                done: { rule in
                    draft.rule = rule
                    isCustomizing = false
                },
                cancel: { isCustomizing = false })
        }
    }
}

/// Step 1: Today, Later today, Tomorrow and Next week, then the month.
private struct ScheduleDateStep: View {
    var store: BoardStore
    @Binding var draft: BoardStore.Schedule
    var next: () -> Void

    private var calendar: Calendar { store.calendar }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 2) {
                quickRow("Today", symbol: "sun.max", detail: dayLabel(store.today)) { pick(store.today) }
                if let later = laterToday {
                    quickRow("Later today", symbol: "clock", detail: timeLabel(later)) {
                        pick(store.today, minute: later)
                    }
                }
                let tomorrow = store.today.adding(days: 1, calendar: calendar)
                quickRow("Tomorrow", symbol: "sunrise", detail: dayLabel(tomorrow)) { pick(tomorrow) }
                let nextWeek = store.today.adding(days: 7, calendar: calendar)
                quickRow("Next week", symbol: "calendar.badge.plus", detail: dayLabel(nextWeek)) { pick(nextWeek) }
            }
            .padding(6)
            Divider().overlay(Palette.border).padding(.horizontal, 12)
            ScheduleCalendar(
                selection: $draft.date, today: store.today,
                busyDays: Set(store.tasks.filter { !$0.isDone }.compactMap(\.scheduledDate)), calendar: calendar
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            Divider().overlay(Palette.border)
            HStack {
                Label(fullDayLabel(draft.date), systemImage: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Button("Next", action: next)
                    .buttonStyle(.komodo(.primary, size: .small))
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    /// Two hours from now, on the next quarter hour; gone once that runs past midnight.
    private var laterToday: Int? {
        let components = calendar.dateComponents([.hour, .minute], from: store.now)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0) + 120
        let rounded = (minute + 14) / 15 * 15
        return rounded < 24 * 60 ? rounded : nil
    }

    private func pick(_ date: LocalDate, minute: Int? = nil) {
        draft.date = date
        if let minute { draft.minute = minute }
        next()
    }

    private func quickRow(_ title: String, symbol: String, detail: String, action: @escaping () -> Void)
        -> some View
    {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textTertiary)
                    .frame(width: 18)
                Text(title).foregroundStyle(Palette.textPrimary)
                Spacer()
                Text(detail).foregroundStyle(Palette.textMuted).monospacedDigit()
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 10)
            .frame(height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuRowButtonStyle())
    }

    private func dayLabel(_ date: LocalDate) -> String {
        date.startOfDay(in: calendar).formatted(.dateTime.weekday(.abbreviated).day())
    }

    private func fullDayLabel(_ date: LocalDate) -> String {
        date.startOfDay(in: calendar).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private func timeLabel(_ minute: Int) -> String {
        store.today.startOfDay(in: calendar).addingTimeInterval(TimeInterval(minute * 60))
            .formatted(date: .omitted, time: .shortened)
    }
}

/// The month on the canvas: Monday first, a lime ring on today, a lime fill on the pick, and a blue dot on days
/// that already have something scheduled. Past days can't be picked.
private struct ScheduleCalendar: View {
    @Binding var selection: LocalDate
    var today: LocalDate
    var busyDays: Set<LocalDate>
    var calendar: Calendar
    @State private var month: LocalDate

    init(selection: Binding<LocalDate>, today: LocalDate, busyDays: Set<LocalDate>, calendar: Calendar) {
        _selection = selection
        self.today = today
        self.busyDays = busyDays
        self.calendar = calendar
        _month = State(
            initialValue: LocalDate(year: selection.wrappedValue.year, month: selection.wrappedValue.month, day: 1))
    }

    private var cells: [LocalDate] {
        let lead = month.isoWeekday(calendar: calendar) - 1
        let length = calendar.range(of: .day, in: .month, for: month.startOfDay(in: calendar))?.count ?? 31
        let first = month.adding(days: -lead, calendar: calendar)
        return (0..<(lead + length + 6) / 7 * 7).map { first.adding(days: $0, calendar: calendar) }
    }

    /// The calendar's own letters, turned to start on Monday whatever the locale's first weekday.
    private var weekdayLetters: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        return Array(symbols.dropFirst() + symbols.prefix(1))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                let start = month.startOfDay(in: calendar)
                (Text(start.formatted(.dateTime.month(.wide)))
                    + Text(" \(start.formatted(.dateTime.year()))").foregroundStyle(Palette.textMuted))
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                monthButton("Previous month", symbol: "chevron.left", by: -1)
                monthButton("Next month", symbol: "chevron.right", by: 1)
            }
            .padding(.leading, 6)
            .frame(height: 34)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(Array(weekdayLetters.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(Palette.textMuted)
                        .frame(height: 22)
                }
                ForEach(cells, id: \.self) { day in
                    Button {
                        selection = day
                    } label: {
                        Text("\(day.day)")
                    }
                    .buttonStyle(
                        CalendarDayStyle(
                            isToday: day == today, isSelected: day == selection,
                            isDimmed: day.month != month.month || day < today,
                            hasDot: busyDays.contains(day) && day != selection)
                    )
                    .disabled(day < today)
                    .accessibilityLabel(day.startOfDay(in: calendar).formatted(date: .complete, time: .omitted))
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
        .padding(.bottom, 4)
        .spotlight(SpotlightTint.week, radius: Radius.control, lifts: false)
    }

    private func monthButton(_ title: String, symbol: String, by months: Int) -> some View {
        Button(title, systemImage: symbol) {
            let start = calendar.date(byAdding: .month, value: months, to: month.startOfDay(in: calendar))
            if let start { month = LocalDate(start, calendar: calendar) }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Palette.textSecondary)
        .frame(width: 26, height: 26)
        .contentShape(Rectangle())
    }
}

/// `.sh-day`: a 34 pt circle that fills faintly on hover and pops when pressed.
private struct CalendarDayStyle: ButtonStyle {
    var isToday: Bool
    var isSelected: Bool
    var isDimmed: Bool
    var hasDot: Bool

    func makeBody(configuration: Configuration) -> some View {
        Day(configuration: configuration, style: self)
    }

    private struct Day: View {
        var configuration: Configuration
        var style: CalendarDayStyle
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var isHovered = false

        private var foreground: Color {
            if style.isSelected { return Palette.onAccent }
            if style.isToday { return Palette.limeText }
            if style.isDimmed { return Palette.textMuted }
            return isHovered ? Palette.textPrimary : Palette.textBody
        }

        private var scale: CGFloat {
            guard isEnabled, !reduceMotion else { return 1 }
            return configuration.isPressed ? 0.92 : isHovered && !style.isSelected ? 1.08 : 1
        }

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: style.isSelected ? .heavy : style.isToday ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(foreground)
                .frame(width: 34, height: 34)
                .background {
                    if style.isSelected {
                        Circle().fill(Palette.lime).shadow(color: Palette.lime.opacity(0.6), radius: 10)
                    } else if style.isToday {
                        Circle().strokeBorder(Palette.lime, lineWidth: 1.5)
                            .shadow(color: Palette.lime.opacity(0.5), radius: 5)
                    } else if isHovered && isEnabled {
                        Circle().fill(Color.white.opacity(0.09))
                    }
                }
                .overlay(alignment: .bottom) {
                    if style.hasDot {
                        Circle().fill(Palette.blue).frame(width: 4, height: 4)
                            .shadow(color: Palette.blue.opacity(0.9), radius: 3)
                            .padding(.bottom, 4)
                    }
                }
                .scaleEffect(scale)
                .contentShape(Circle())
                .onHover { isHovered = $0 }
                .animation(Motion.spring, value: scale)
                .animation(Motion.fast, value: isHovered)
        }
    }
}

/// A menu-like row: no chrome, a faint fill on hover (`.k-row`).
struct MenuRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MenuRow(configuration: configuration)
    }

    private struct MenuRow: View {
        var configuration: Configuration
        @State private var isHovered = false

        var body: some View {
            configuration.label
                .background(
                    Color.white.opacity(configuration.isPressed ? 0.08 : isHovered ? 0.05 : 0),
                    in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                )
                .onHover { isHovered = $0 }
                .animation(Motion.fast, value: isHovered)
        }
    }
}

#Preview("Schedule popover") {
    let store = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)
    HStack(alignment: .top, spacing: Space.s6) {
        ForEach(["hire", "wireframes", "weekly"], id: \.self) { id in
            if let task = store.tasks.first(where: { $0.id == id }) {
                SchedulePopover(store: store, task: task) {}
                    .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            }
        }
    }
    .padding(Space.s8)
    .background(Palette.bg)
}
