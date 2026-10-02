import KomodoCore
import SwiftUI

/// List, Estimate with Taken, Schedule and Repeat (DESIGN_SYSTEM §13.5). A running task's EST and time taken are
/// locked (FEATURES §4.3); the lock sits beside the estimate as on the canvas.
struct InspectorDetails: View {
    var store: BoardStore
    var task: TaskItem

    @State private var isEditingTaken = false
    @State private var isScheduling = false
    @Environment(\.isOffscreen) private var isOffscreen

    private var isRunning: Bool { store.isRunning(task) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            InspectorRow("List") { listMenu }
            InspectorRow("Estimate") {
                estimate
                Spacer(minLength: 0)
                Text("Taken").font(.system(size: 12)).foregroundStyle(Palette.textMuted)
                taken
            }
            InspectorRow("Schedule") { schedule }
            InspectorRow("Repeat") {
                Button {
                    isScheduling = true
                } label: {
                    InspectorValue(
                        tint: store.repeatSummary(for: task) == nil ? nil : Palette.violet,
                        textTint: Palette.violetText
                    ) {
                        Image(systemName: "repeat").font(.system(size: 11, weight: .semibold))
                        Text(store.repeatSummary(for: task) ?? "Doesn't repeat")
                        Chevron()
                    }
                }
                .buttonStyle(.plain)
                .help("Change how this task repeats")
            }
        }
        .inspectorSection(SpotlightTint.today)
        .onChange(of: task.id) {
            isEditingTaken = false
            isScheduling = false
        }
        .popover(isPresented: $isScheduling, arrowEdge: .leading) {
            SchedulePopover(store: store, task: task) { isScheduling = false }
        }
    }

    private var listMenu: some View {
        Menu {
            ForEach(store.lists) { list in
                Button(list.name) { store.update(task.id) { $0.listID = list.id } }
            }
        } label: {
            InspectorValue {
                if let list = store.list(for: task) {
                    ListBadge(letter: list.letter, color: ListColor(rawValue: list.color) ?? .lime, side: 18)
                    Text(list.name)
                }
                Chevron()
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("List")
    }

    @ViewBuilder private var estimate: some View {
        if isRunning {
            Text(DurationFormat.hoursMinutes(task.estimate ?? 0))
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(Palette.textBody)
                .frame(width: 56, height: 28)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .opacity(0.55)
            Image(systemName: "lock")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Palette.textMuted)
                .help("Pause to edit")
        } else {
            DurationField(
                duration: Binding(
                    get: { task.estimate ?? 0 },
                    set: { store.setEstimate(task.id, to: $0) }))
        }
    }

    @ViewBuilder private var taken: some View {
        if isRunning {
            let clock = store.focusClock(for: task)
            TimelineView(
                .periodic(from: clock.runningSince ?? .now, by: Motion.tick(isMoving: true, isOffscreen: isOffscreen))
            ) { context in
                Text(TimerFormat.clock(Int(clock.elapsed(at: context.date))))
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(Palette.limeText)
            }
        } else if isEditingTaken {
            DurationField(
                duration: Binding(
                    get: { task.timeTaken(at: store.now) },
                    set: {
                        store.setTimeTaken(task.id, to: $0)
                        isEditingTaken = false
                    }),
                focusesOnAppear: true
            )
            .onExitCommand { isEditingTaken = false }
            .accessibilityLabel("Time taken, hours and minutes")
        } else {
            Button {
                isEditingTaken = true
            } label: {
                Text(DurationFormat.hoursMinutes(task.timeTaken(at: store.now)))
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(Palette.textBody)
            }
            .buttonStyle(.plain)
            .help("Edit time taken")
        }
    }

    @ViewBuilder private var schedule: some View {
        Button {
            isScheduling = true
        } label: {
            if let date = task.scheduledDate {
                InspectorValue(tint: Palette.blue) {
                    Image(systemName: "calendar").font(.system(size: 11, weight: .semibold))
                    Text(store.scheduleText(date: date, minute: task.scheduledMinute))
                }
            } else {
                InspectorValue {
                    Image(systemName: "calendar").font(.system(size: 11, weight: .semibold))
                    Text("Not scheduled")
                }
                .foregroundStyle(Palette.textMuted)
            }
        }
        .buttonStyle(.plain)
        .help("Schedule")
        if task.scheduledDate != nil {
            Button("Clear schedule", systemImage: "xmark") { store.removeSchedule(task.id) }
                .buttonStyle(.icon(.compact))
        }
    }

}

/// A key on the left (78 pt) and its value, at least 30 pt tall (`.in-row`).
struct InspectorRow<Content: View>: View {
    var key: String
    @ViewBuilder var content: Content

    init(_ key: String, @ViewBuilder content: () -> Content) {
        self.key = key
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(key)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.textMuted)
                .frame(width: 78, alignment: .leading)
            content
        }
        .frame(minHeight: 30)
    }
}

/// The 28 pt value pill (`.in-val`): neutral, or tinted like the blue schedule date.
struct InspectorValue<Content: View>: View {
    var tint: Color?
    /// The lighter text step that goes with `tint` (DESIGN_SYSTEM §2.2).
    var textTint: Color
    @ViewBuilder var content: Content

    init(tint: Color? = nil, textTint: Color = Palette.blueText, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.textTint = textTint
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        HStack(spacing: 6) { content }
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(tint == nil ? Palette.textBody : textTint)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(tint.map { $0.opacity(0.1) } ?? Color.white.opacity(0.05), in: shape)
            .overlay(shape.strokeBorder(tint.map { $0.opacity(0.3) } ?? Color.white.opacity(0.08), lineWidth: 1))
            .fixedSize()
    }
}

struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(Palette.textMuted)
    }
}

extension View {
    /// An inspector group (`.in-sec`): 12 × 14 pt padding on a faint tile that lights up under the pointer.
    func inspectorSection(_ tint: Color) -> some View {
        padding(.vertical, Space.s3)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .spotlight(tint, radius: 16, lifts: false) { TileSurface(radius: 16) }
    }
}

#Preview("Inspector details") {
    let store = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)
    VStack(spacing: Space.s3) {
        ForEach(["wireframes", "design-review", "visa"], id: \.self) { id in
            if let task = store.tasks.first(where: { $0.id == id }) {
                InspectorDetails(store: store, task: task)
            }
        }
    }
    .frame(width: 356)
    .padding(Space.s6)
    .background(Palette.panel)
}
