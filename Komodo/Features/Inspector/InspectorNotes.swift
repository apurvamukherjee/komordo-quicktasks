import KomodoCore
import SwiftUI

/// NOTES (FEATURES §4.5): the rich-text editor, always editable, and the per-task switch for opening links
/// when the task starts.
struct InspectorNotes: View {
    var store: BoardStore
    var task: TaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NOTES").font(Typography.label).tracking(Typography.Tracking.label)
                .foregroundStyle(Palette.textSecondary)
            NotesEditor(text: task.notes ?? "", rtf: task.notesRTF) { text, rtf in
                store.update(task.id) {
                    $0.notes = text.isEmpty ? nil : text
                    $0.notesRTF = rtf
                }
            }
            .id(task.id)
            HStack(spacing: 10) {
                Toggle(
                    "Open links when this task starts",
                    isOn: Binding(
                        get: { task.opensLinks },
                        set: { on in store.update(task.id) { $0.opensLinks = on } })
                )
                .labelsHidden()
                .komodoSwitch()
                Text("Open links when this task starts")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.textTertiary)
            }
        }
        .inspectorSection(SpotlightTint.info)
    }
}

#Preview("Inspector notes") {
    struct Demo: View {
        @State private var store = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)

        var body: some View {
            VStack(spacing: Space.s3) {
                ForEach(["design-review", "visa"], id: \.self) { id in
                    if let task = store.tasks.first(where: { $0.id == id }) {
                        InspectorNotes(store: store, task: task)
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
