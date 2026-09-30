import KomodoCore
import SwiftUI

/// Add or edit a session (DESIGN_SYSTEM §13.13): a task found by search, Work or Break, the date, start and end,
/// and a duration that moves the end. A break isn't tied to a task.
struct SessionSheet: View {
    var store: BoardStore
    /// nil adds a new session.
    var entry: SessionLog.Entry?
    var close: () -> Void

    @State private var taskID: String?
    @State private var isBreak: Bool
    @State private var day: Date
    @State private var start: Date
    @State private var end: Date
    @State private var query = ""

    init(store: BoardStore, entry: SessionLog.Entry?, close: @escaping () -> Void) {
        self.store = store
        self.entry = entry
        self.close = close
        let start = entry?.start ?? store.now.addingTimeInterval(-45 * 60)
        let end = entry?.end ?? store.now
        var taskID: String?
        if case .work(let id, _, _, _) = entry?.kind { taskID = id }
        _taskID = State(initialValue: taskID)
        _isBreak = State(initialValue: entry?.isBreak ?? false)
        _day = State(initialValue: start)
        _start = State(initialValue: start)
        _end = State(initialValue: end)
    }

    private var task: TaskItem? { taskID.flatMap(store.reportTask) }

    /// The chosen day with the start and end times; an end before the start runs past midnight.
    private var interval: (start: Date, end: Date) {
        let from = combine(day, start)
        var to = combine(day, end)
        if to <= from { to = store.calendar.date(byAdding: .day, value: 1, to: to) ?? to }
        return (from, to)
    }

    private var canSave: Bool { isBreak || task != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            header
            if !isBreak { taskField }
            HStack {
                label("TYPE")
                Spacer()
                Picker("Type", selection: $isBreak) {
                    Text("Work").tag(false)
                    Text("Break").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            field("DATE") {
                DatePicker("Date", selection: $day, displayedComponents: .date).labelsHidden()
            }
            HStack(alignment: .top, spacing: 10) {
                field("START") {
                    DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute).labelsHidden()
                }
                field("END") {
                    DatePicker("End", selection: $end, displayedComponents: .hourAndMinute).labelsHidden()
                }
                field("DURATION") { durationStepper }
            }
            HStack(spacing: Space.s2) {
                if entry != nil {
                    Button("Delete", role: .destructive) {
                        remove(undoable: true)
                        close()
                    }
                    .buttonStyle(.komodo(.dangerOutline))
                }
                Spacer()
                Button("Cancel", action: close)
                    .buttonStyle(.komodo(.secondary))
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .buttonStyle(.komodo(.primary))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .datePickerStyle(.field)
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .frame(width: Layout.sheetFormWidth)
        .background(Palette.raised)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Space.s3) {
            Image(systemName: entry == nil ? "plus" : "pencil")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.tealText)
                .frame(width: 34, height: 34)
                .background(Palette.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Palette.teal.opacity(0.28)))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry == nil ? "Add session" : "Edit session")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text(subtitle).font(.system(size: 12.5)).foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            KeyCap("esc")
        }
    }

    private var subtitle: String {
        switch entry?.kind {
        case nil: "Log work you did away from your Mac."
        case .breakTime: "Break · " + day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .work(_, _, let title, let number): "Session \(number) · \(title)"
        }
    }

    // MARK: Task

    private var taskField: some View {
        field("TASK") {
            VStack(alignment: .leading, spacing: Space.s1) {
                if let task, query.isEmpty {
                    Button {
                        taskID = nil
                    } label: {
                        HStack(spacing: Space.s2) {
                            if let list = store.list(for: task) {
                                ListBadge(
                                    letter: list.letter, color: ListColor(rawValue: list.color) ?? .lime, side: 20)
                            }
                            Text(task.title).font(.system(size: 13)).foregroundStyle(Palette.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Palette.textMuted)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 38)
                        .background(
                            Color.white.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Choose another task")
                } else {
                    KomodoTextField("Search tasks…", text: $query, variant: .search, focusesOnAppear: true)
                    ForEach(matches, id: \.id) { match in
                        Button {
                            taskID = match.id
                            query = ""
                        } label: {
                            HStack(spacing: 9) {
                                if let list = store.list(for: match) {
                                    ListBadge(
                                        letter: list.letter, color: ListColor(rawValue: list.color) ?? .lime, side: 18)
                                }
                                Text(match.title).lineLimit(1)
                                Spacer()
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(Palette.textBody)
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    if !query.isEmpty && matches.isEmpty {
                        Text("No matching tasks.").font(.system(size: 12.5)).foregroundStyle(Palette.textMuted)
                            .padding(10)
                    }
                }
            }
        }
    }

    /// Up to five tasks whose titles contain the query, most recently touched first.
    private var matches: [TaskItem] {
        guard !query.isEmpty else { return [] }
        return store.reportTasks
            .filter { $0.title.localizedCaseInsensitiveContains(query) }
            .sorted { ($0.sessions.last?.start ?? .distantPast) > ($1.sessions.last?.start ?? .distantPast) }
            .prefix(5)
            .map { $0 }
    }

    // MARK: Duration

    private var durationStepper: some View {
        let length = interval.end.timeIntervalSince(interval.start)
        return HStack(spacing: 6) {
            Button("5 minutes less", systemImage: "minus") { setLength(length - 5 * 60) }
                .buttonStyle(.icon(.compact))
                .disabled(length <= 5 * 60)
            Text(DurationFormat.short(length))
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(Palette.textPrimary)
                .frame(minWidth: 64)
            Button("5 minutes more", systemImage: "plus") { setLength(length + 5 * 60) }
                .buttonStyle(.icon(.compact))
        }
        .frame(height: 22)
    }

    /// Editing the duration moves the end, as DESIGN_SYSTEM §13.13 asks.
    private func setLength(_ length: TimeInterval) {
        end = interval.start.addingTimeInterval(max(60, length))
    }

    // MARK: Saving

    private func save() {
        let (from, to) = interval
        remove(undoable: false)
        if isBreak {
            var breakID: String?
            if case .breakTime(let id) = entry?.kind { breakID = id }
            store.saveBreak(BreakSession(id: breakID ?? UUID().uuidString, start: from, end: to, taskID: nil))
        } else if let taskID {
            store.saveSession(WorkSession(start: from, end: to), of: taskID)
        }
        close()
    }

    /// Takes the original out, so a changed task or type moves it rather than copying it.
    private func remove(undoable: Bool) {
        switch entry?.kind {
        case .work(let id, _, _, let number):
            if undoable {
                store.deleteSession(number, of: id)
            } else if let sessions = store.reportTask(id)?.sessions.sorted(by: { $0.start < $1.start }) {
                store.setSessions(of: id, sessions.enumerated().filter { $0.offset != number - 1 }.map(\.element))
            }
        case .breakTime(let id):
            if undoable {
                store.deleteBreak(id)
            } else {
                store.removeBreak(id)
            }
        case nil:
            break
        }
    }

    private func combine(_ date: Date, _ time: Date) -> Date {
        let calendar = store.calendar
        let clock = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(
            bySettingHour: clock.hour ?? 0, minute: clock.minute ?? 0, second: 0, of: calendar.startOfDay(for: date))
            ?? date
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold))
            .tracking(Typography.Tracking.label)
            .foregroundStyle(Palette.textMuted)
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            label(title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
