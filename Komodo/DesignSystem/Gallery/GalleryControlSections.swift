#if DEBUG
    import SwiftUI

    struct ButtonsSection: View {
        var body: some View {
            GallerySection(label: "BUTTONS · HOVER & PRESS ARE LIVE") {
                HStack(spacing: 10) {
                    Button("Start", systemImage: "play.fill") {}.buttonStyle(.komodo(.primary, size: .large))
                    Button("Schedule") {}.buttonStyle(.komodo(.secondary, size: .large))
                    Button("Cancel") {}.buttonStyle(.komodo(.ghost, size: .large))
                    Button("Delete all") {}.buttonStyle(.komodo(.danger, size: .large))
                    Button("Empty Trash") {}.buttonStyle(.komodo(.dangerOutline, size: .large))
                }
                HStack(spacing: 10) {
                    Button("sm 28") {}.buttonStyle(.komodo(.primary, size: .small))
                    Button("md 34") {}.buttonStyle(.komodo(.primary))
                    Button("lg 40") {}.buttonStyle(.komodo(.primary, size: .large))
                    Button("Disabled") {}.buttonStyle(.komodo()).disabled(true)
                    Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 28).padding(.horizontal, 4)
                    Button("Schedule", systemImage: "calendar") {}.buttonStyle(.cardAction)
                    Button("Subtasks", systemImage: "checklist") {}.buttonStyle(.cardAction)
                    Button("Notes", systemImage: "note.text") {}.buttonStyle(.cardAction)
                    Button("Make live", systemImage: "bolt.fill") {}.buttonStyle(.cardActionGo)
                }
                ControlBar(mode: .running, actions: ControlBarActions())
                    .padding(12)
                    .background(
                        Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
                Text(
                    "Control bar: one primary per state. Paused → Resume is primary, Done drops to soft. "
                        + "Time's up → +5 · +15 · Done · Next."
                )
                .font(GalleryType.use)
                .foregroundStyle(Palette.textSecondary)
            }
        }
    }

    struct ControlsSection: View {
        private enum Mode: String, CaseIterable {
            case onThisMac = "On this Mac"
            case claude = "Claude"
        }

        @State private var pomodoros = true
        @State private var successSound = false
        @State private var collectFeedback = true
        @State private var mode = Mode.onThisMac
        @State private var title = ""
        @State private var focused = "Write launch email 45m"
        @State private var clientID = "1234-abc"

        var body: some View {
            GallerySection(label: "CONTROLS · CLICK THEM") {
                HStack(spacing: 28) {
                    Toggle("Pomodoros", isOn: $pomodoros).komodoSwitch()
                    Toggle("Success sound", isOn: $successSound).komodoSwitch()
                    Toggle(isOn: $collectFeedback) {
                        Text("Collect feedback")
                            .strikethrough(collectFeedback)
                            .foregroundStyle(collectFeedback ? Palette.textMuted : Palette.textPrimary)
                    }
                    .toggleStyle(.checkbox)
                }
                .font(.system(size: 13))
                HStack(spacing: 16) {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    Text(modeNote)
                        .font(.system(size: 12))
                        .foregroundStyle(mode == .onThisMac ? Palette.greenText : Palette.amberText)
                }
                FlowLayout {
                    Chip("2hr 30min", icon: "clock")
                    Chip("Sun 10:00 AM", tint: .blue)
                    Chip("Due Oct 10", tint: .amber)
                    Chip("Every Friday", tint: .violet)
                    Chip("Overdue · 9:00 AM", tint: .red)
                    Chip("45min parsed", tint: .lime)
                    Chip("Added", tint: .green)
                    Chip("Review", tint: .amber)
                    Chip("Skipped", tint: .outline)
                    Chip("New", tint: .pink)
                    Chip("Scanning", tint: .teal)
                }
                HStack(spacing: 18) {
                    StatusDot(status: .active, label: "Active")
                    StatusDot(status: .working, label: "Scanning")
                    StatusDot(status: .paused, label: "Paused")
                    StatusDot(status: .attention, label: "Needs attention")
                    StatusDot(status: .offline, label: "Offline")
                }
                WeightedHStack(weights: [1, 1, 1], spacing: 10) {
                    KomodoTextField("Task title", text: $title)
                    KomodoTextField(placeholder: "Task title", text: $focused) {
                        Chip("45min", tint: .lime, size: .compact)
                    }
                    KomodoTextField("Client ID", text: $clientID, error: "That client ID isn't valid.")
                }
            }
        }

        private var modeNote: String {
            switch mode {
            case .onThisMac: "Email never leaves this Mac."
            case .claude: "Claude mode sends each email’s text to Anthropic, using your API key."
            }
        }
    }

    #Preview("Buttons and controls") {
        WeightedHStack(weights: [1, 1], spacing: 20) {
            ButtonsSection()
            ControlsSection()
        }
        .padding(64)
        .frame(width: GalleryCanvas.width)
        .background(Palette.bg)
    }
#endif
