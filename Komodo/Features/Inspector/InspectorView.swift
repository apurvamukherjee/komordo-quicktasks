import KomodoCore
import SwiftUI

/// Everything about one task (DESIGN_SYSTEM §13.5): the live timer when it's running, the title, details,
/// subtasks, notes, source, sessions and when it was made.
struct InspectorView: View {
    var store: BoardStore

    var body: some View {
        if let task = store.inspectedTask {
            ScrollView {
                VStack(spacing: 0) {
                    if store.liveTask?.id == task.id {
                        InspectorLiveHeader(store: store, task: task)
                            .padding([.horizontal, .top], Space.s3)
                    }
                    InspectorHeader(store: store, task: task)
                    VStack(spacing: 10) {
                        InspectorDetails(store: store, task: task)
                        InspectorSubtasks(store: store, task: task)
                        InspectorNotes(store: store, task: task)
                        if let source = task.source {
                            InspectorSource(task: task, source: source)
                        }
                        InspectorSessions(task: task, now: store.now)
                    }
                    .padding(Space.s3)
                    Text(footer(for: task))
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Space.s4)
                        .padding(.top, 10)
                        .padding(.bottom, 14)
                        .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
                }
            }
            .scrollIndicators(.never)
            .background(
                LinearGradient(colors: [Palette.card, Palette.panel], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea())
        }
    }

    /// "Created Sep 20 · Edited 2 min ago", "Created Sep 12 · Live since 1:52 PM" or
    /// "Created by Gmail → Calendar · Sep 24".
    private func footer(for task: TaskItem) -> String {
        let created = task.createdAt?.formatted(.dateTime.month(.abbreviated).day())
        var parts: [String] = []
        if task.source == .gmail {
            parts.append("Created by Gmail → Calendar")
            if let created { parts.append(created) }
            return parts.joined(separator: " · ")
        }
        if let created { parts.append("Created \(created)") }
        if let start = task.sessions.first(where: { $0.end == nil })?.start {
            parts.append("Live since \(start.formatted(date: .omitted, time: .shortened))")
        } else if let edited = task.editedAt {
            parts.append("Edited \(Self.ago(edited, now: store.now))")
        }
        return parts.joined(separator: " · ")
    }

    /// "just now", "2 min ago", "3 hr ago", then the date, in the app's short units (DESIGN_SYSTEM §3).
    private static func ago(_ date: Date, now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes) min ago" }
        if minutes < 24 * 60 { return "\(minutes / 60) hr ago" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

/// The checkbox, the title (click to rename, Return saves, Esc cancels), ⋯ and ✕. A running task's title is
/// locked with "Pause to edit" (FEATURES §4.3).
struct InspectorHeader: View {
    var store: BoardStore
    var task: TaskItem

    @State private var draft: String?
    @FocusState private var isEditing: Bool

    var body: some View {
        let isRunning = store.isRunning(task)
        HStack(alignment: .top, spacing: 10) {
            Toggle(
                "Done",
                isOn: Binding(get: { task.isDone }, set: { _ in store.toggleDone(task.id) })
            )
            .toggleStyle(.checkbox)
            .labelsHidden()
            .padding(.top, 3)
            VStack(alignment: .leading, spacing: 6) {
                title(isRunning: isRunning)
                if isRunning {
                    Label("Pause to edit", systemImage: "lock")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(Palette.textSecondary)
                        .labelStyle(TightLabelStyle())
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                        .help("Pause to edit")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            moreMenu
            Button("Close inspector", systemImage: "xmark") { store.inspect(nil) }
                .buttonStyle(.icon())
                .help("Close (Esc)")
        }
        .padding(.leading, Space.s4)
        .padding(.trailing, 14)
        .padding(.top, Space.s4)
        .padding(.bottom, Space.s3)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
        .onChange(of: task.id) { draft = nil }
    }

    @ViewBuilder private func title(isRunning: Bool) -> some View {
        let font = Font.system(size: 17, weight: .bold)
        if let draft {
            TextField("Title", text: Binding(get: { draft }, set: { self.draft = $0 }), axis: .vertical)
                .textFieldStyle(.plain)
                .font(font)
                .foregroundStyle(Palette.textPrimary)
                .focused($isEditing)
                .onAppear { isEditing = true }
                .onSubmit {
                    store.rename(task.id, to: draft)
                    self.draft = nil
                }
                .onExitCommand { self.draft = nil }
        } else {
            Text(task.title)
                .font(font)
                .tracking(-0.25)
                .lineSpacing(3)
                .strikethrough(task.isDone)
                .foregroundStyle(task.isDone ? Palette.textMuted : Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .contentShape(Rectangle())
                .onTapGesture { if !isRunning { draft = task.title } }
                .accessibilityAddTraits(isRunning ? [] : .isButton)
                .accessibilityHint(isRunning ? "" : "Rename")
        }
    }

    private var moreMenu: some View {
        Menu {
            Button("Duplicate") { store.duplicate(task.id) }
            Menu("Move to List") {
                ForEach(store.lists) { list in
                    Button(list.name) { store.update(task.id) { $0.listID = list.id } }
                        .disabled(list.id == task.listID)
                }
            }
            Button("Archive") {}
                .disabled(true)
                .help("Archive arrives with Trash")
            Divider()
            Button("Delete", role: .destructive) { store.delete(task.id) }
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.icon())
        .fixedSize()
        .accessibilityLabel("More")
    }
}

/// The running timer above the title (Inspector.dc.html): beam border, progress ring, `LIVE · FOCUS MODE`, the
/// time left rolling like an odometer, and pause.
struct InspectorLiveHeader: View {
    var store: BoardStore
    var task: TaskItem

    @Environment(\.isOffscreen) private var isOffscreen

    var body: some View {
        let clock = store.focusClock(for: task)
        let estimate = task.estimate ?? 3_600
        let tone: TimerTone = clock.isRunning ? .live : .paused
        HStack(spacing: Space.s3) {
            FocusDial(clock: clock, estimate: estimate, tone: tone, metrics: .inspector) { _ in EmptyView() }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle().fill(Palette.lime).frame(width: 6, height: 6).ping(Palette.lime)
                    Text(clock.isRunning ? "LIVE · FOCUS MODE" : "PAUSED · FOCUS MODE")
                }
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(clock.isRunning ? Palette.limeText : Palette.textSecondary)
                TimelineView(
                    .periodic(
                        from: clock.runningSince ?? .now, by: Motion.tick(isMoving: true, isOffscreen: isOffscreen))
                ) { context in
                    OdometerText(
                        TimerFormat.remaining(estimate: estimate, elapsed: clock.elapsed(at: context.date)),
                        colon: .steady(opacity: 0.6)
                    )
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.9)
                    .foregroundStyle(Palette.textPrimary)
                }
                .shadow(color: Palette.lime.opacity(0.4), radius: 11)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(clock.isRunning ? "Pause" : "Resume", systemImage: clock.isRunning ? "pause.fill" : "play.fill") {
                store.togglePause()
            }
            .buttonStyle(.cardAction)
        }
        .padding(.vertical, Space.s3)
        .padding(.horizontal, 14)
        .background {
            ZStack {
                Palette.panel
                EllipticalGradient(
                    colors: [Palette.teal.opacity(0.2), .clear], center: .topLeading, startRadiusFraction: 0,
                    endRadiusFraction: 0.6)
            }
        }
        .beamBorder(tone, radius: Radius.card)
        .spotlight(SpotlightTint.today, radius: Radius.card, lifts: false)
    }
}

#Preview("Inspector · normal, live, from Gmail") {
    struct Panel: View {
        @State private var store = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)
        var id: String

        var body: some View {
            InspectorView(store: store)
                .frame(width: Layout.inspectorIdeal, height: 1_000)
                .onAppear { store.inspect(id) }
        }
    }
    return HStack(alignment: .top, spacing: Space.s8) {
        Panel(id: "wireframes")
        Panel(id: "design-review")
        Panel(id: "visa")
    }
    .padding(Space.s8)
    .background(Palette.bg)
}
