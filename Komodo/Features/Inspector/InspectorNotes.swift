import KomodoCore
import SwiftUI

/// NOTES (FEATURES §4.5): the rich-text editor, always editable, and the per-task switch for opening links
/// when the task starts.
struct InspectorNotes: View {
    var store: BoardStore
    var task: TaskItem

    @State private var voice = SpeechTranscriber()
    @State private var editor = NotesEditorController()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("NOTES").font(Typography.label).tracking(Typography.Tracking.label)
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                voiceButton
            }
            if voice.isListening {
                HStack(alignment: .top, spacing: Space.s2) {
                    WaveformBars(levels: Array(voice.levels.suffix(5)), height: 14)
                    Text(voice.transcript.isEmpty ? "Listening…" : voice.transcript)
                        .font(.system(size: 12.5))
                        .foregroundStyle(voice.transcript.isEmpty ? Palette.limeText : Palette.textBody)
                }
            } else if case .failed(let message) = voice.state {
                Text(message).font(.system(size: 12)).foregroundStyle(Palette.dangerText)
            }
            NotesEditor(text: task.notes ?? "", rtf: task.notesRTF, controller: editor) { text, rtf in
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
        .onChange(of: task.id) { if voice.isListening { voice.stop() } }
        #if DEBUG
            // `-voiceNote <seconds>` with `-voiceSample "<text>"` records a voice note on the open task and adds it
            // after that long, for captures without the microphone.
            .task {
                let seconds = UserDefaults.standard.double(forKey: "voiceNote")
                guard seconds > 0 else { return }
                await voice.start()
                try? await Task.sleep(for: .seconds(seconds))
                addVoiceNote()
            }
        #endif
    }

    private func addVoiceNote() {
        let heard = voice.stop()
        if !heard.isEmpty { editor.append(heard) }
    }

    /// Voice note (FEATURES §4.5): click to listen, click again to add what was heard to the notes.
    private var voiceButton: some View {
        Button {
            if voice.isListening {
                addVoiceNote()
            } else {
                Task { await voice.start() }
            }
        } label: {
            Label(
                voice.isListening ? "Add to notes" : "Voice note", systemImage: voice.isListening ? "stop.fill" : "mic")
        }
        .buttonStyle(.komodo(voice.isListening ? .primary : .ghost, size: .small))
        .help(
            voice.isListening
                ? "Stop and add what was heard to the notes" : "Speak a note; it's transcribed on this Mac")
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
