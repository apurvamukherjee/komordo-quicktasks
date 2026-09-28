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
            DatePicker(
                "Day",
                selection: Binding(
                    get: { draft.date.startOfDay(in: calendar) },
                    set: { draft.date = LocalDate($0, calendar: calendar) }),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .environment(\.calendar, calendar)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
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
