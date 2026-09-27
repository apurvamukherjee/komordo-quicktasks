import KomodoCore
import SwiftUI

/// SUBTASKS with the progress dial (FEATURES §4.4): check to fill the dial, click a title to rename it, the
/// trash button deletes, and **+ Add subtask** keeps adding on Return. Editable on the live task too.
struct InspectorSubtasks: View {
    var store: BoardStore
    var task: TaskItem

    @State private var isAdding = false
    @State private var draft = ""
    @FocusState private var isDraftFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("SUBTASKS").font(Typography.label).tracking(Typography.Tracking.label)
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                HStack(spacing: 6) {
                    MiniDial(done: task.subtasksDone, total: task.subtasks.count)
                    Text("\(task.subtasksDone)/\(task.subtasks.count)")
                }
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(Palette.textTertiary)
            }
            VStack(alignment: .leading, spacing: 2) {
                ForEach(task.subtasks) { subtask in
                    SubtaskRow(store: store, taskID: task.id, subtask: subtask)
                }
                if isAdding {
                    TextField("Subtask", text: $draft, prompt: Text("Add subtask").foregroundStyle(Palette.textMuted))
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.horizontal, Space.s2)
                        .frame(height: 32)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
                        .focused($isDraftFocused)
                        .onAppear { isDraftFocused = true }
                        .onSubmit {
                            guard !draft.trimmingCharacters(in: .whitespaces).isEmpty else {
                                isAdding = false
                                return
                            }
                            store.addSubtask(to: task.id, title: draft)
                            draft = ""
                        }
                        .onExitCommand {
                            draft = ""
                            isAdding = false
                        }
                } else {
                    Button {
                        isAdding = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus").font(.system(size: 12, weight: .bold)).foregroundStyle(
                                Palette.lime)
                            Text("Add subtask")
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textMuted)
                        .padding(.horizontal, Space.s2)
                        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .inspectorSection(SpotlightTint.today)
        .onChange(of: task.id) {
            isAdding = false
            draft = ""
        }
    }
}

/// One subtask: the checkbox toggles, a click on the title renames it, and trash shows on hover.
private struct SubtaskRow: View {
    var store: BoardStore
    var taskID: String
    var subtask: Subtask

    @State private var isHovered = false
    @State private var editedTitle: String?
    @FocusState private var isEditing: Bool

    var body: some View {
        HStack(spacing: 10) {
            Toggle(
                subtask.title,
                isOn: Binding(
                    get: { subtask.isDone },
                    set: { done in store.updateSubtask(subtask.id, of: taskID) { $0.isDone = done } })
            )
            .toggleStyle(.checkbox)
            .labelsHidden()
            if let editedTitle {
                TextField(
                    "Subtask",
                    text: Binding(get: { editedTitle }, set: { self.editedTitle = $0 })
                )
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Palette.textPrimary)
                .focused($isEditing)
                .onAppear { isEditing = true }
                .onSubmit {
                    store.updateSubtask(subtask.id, of: taskID) { subtask in
                        let trimmed = editedTitle.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty { subtask.title = trimmed }
                    }
                    self.editedTitle = nil
                }
                .onExitCommand { self.editedTitle = nil }
            } else {
                Text(subtask.title)
                    .font(.system(size: 13))
                    .strikethrough(subtask.isDone)
                    .foregroundStyle(subtask.isDone ? Palette.textMuted : Palette.textBody)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { editedTitle = subtask.title }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Rename")
            }
            if isHovered && editedTitle == nil {
                Button("Delete subtask", systemImage: "trash") {
                    store.deleteSubtask(subtask.id, of: taskID)
                }
                .buttonStyle(.icon(.compact))
                .help("Delete")
            }
        }
        .padding(.horizontal, Space.s2)
        .frame(height: 32)
        .background(
            Color.white.opacity(isHovered ? 0.04 : 0), in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .onHover { isHovered = $0 }
        .animation(Motion.fast, value: isHovered)
    }
}

/// The 16 pt progress dial beside the count: a lime arc over a faint ring.
private struct MiniDial: View {
    var done: Int
    var total: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: total > 0 ? Double(done) / Double(total) : 0)
                .stroke(Palette.lime, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : Motion.spring, value: done)
        }
        .frame(width: 12, height: 12)
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}

#Preview("Inspector subtasks") {
    struct Demo: View {
        @State private var store = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)

        var body: some View {
            VStack(spacing: Space.s3) {
                ForEach(["wireframes", "design-review", "visa"], id: \.self) { id in
                    if let task = store.tasks.first(where: { $0.id == id }) {
                        InspectorSubtasks(store: store, task: task)
                    }
                }
            }
            .frame(width: 356)
            .padding(Space.s6)
            .background(Palette.panel)
        }
    }
    return Demo()
}
