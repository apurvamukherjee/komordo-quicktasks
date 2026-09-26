#if DEBUG
    import SwiftUI

    // Stand-ins for the button, chip and field components so the artboard can be compared today. The real
    // components (DESIGN_SYSTEM §9–10) replace these when the component library lands.

    enum GalleryButtonSize {
        case small
        case medium
        case large

        var height: CGFloat {
            switch self {
            case .small: 28
            case .medium: 34
            case .large: 40
            }
        }

        var radius: CGFloat {
            switch self {
            case .small: Radius.chip
            case .medium: Radius.control
            case .large: 12
            }
        }

        var padding: CGFloat {
            switch self {
            case .small: 10
            case .medium: 14
            case .large: 20
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: 12
            case .medium: 13
            case .large: 14
            }
        }
    }

    enum GalleryButtonKind {
        case primary
        case soft
        case ghost
        case danger
        case dangerGhost
    }

    private struct GalleryButtonStyle: ButtonStyle {
        var kind: GalleryButtonKind
        var size: GalleryButtonSize
        @Environment(\.isEnabled) private var isEnabled

        func makeBody(configuration: Configuration) -> some View {
            let shape = RoundedRectangle(cornerRadius: size.radius, style: .continuous)
            configuration.label
                .font(.system(size: size.fontSize, weight: kind == .primary || kind == .danger ? .bold : .semibold))
                .foregroundStyle(foreground)
                .padding(.horizontal, size.padding)
                .frame(height: size.height)
                .background { background(shape) }
                .overlay { border(shape) }
                .overlay {
                    if kind == .primary { Color.clear.sheen(cornerRadius: size.radius) }
                }
                .shadow(color: glow, radius: 12, y: 6)
                .opacity(isEnabled ? 1 : 0.4)
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
                .animation(Motion.spring, value: configuration.isPressed)
        }

        private var foreground: Color {
            switch kind {
            case .primary, .danger: Palette.onAccent
            case .soft: Palette.textPrimary
            case .ghost: Palette.textTertiary
            case .dangerGhost: Palette.dangerText
            }
        }

        private var glow: Color {
            switch kind {
            case .primary: Palette.lime.opacity(0.35)
            case .danger: Palette.danger.opacity(0.35)
            case .soft, .ghost, .dangerGhost: .clear
            }
        }

        @ViewBuilder private func background(_ shape: RoundedRectangle) -> some View {
            switch kind {
            case .primary:
                shape.fill(
                    LinearGradient(
                        colors: [Palette.teal, Palette.lime], startPoint: .topLeading, endPoint: .bottomTrailing))
            case .soft: shape.fill(Color.white.opacity(0.05))
            case .ghost: shape.fill(Color.clear)
            case .danger: shape.fill(Palette.danger)
            case .dangerGhost: shape.fill(Palette.danger.opacity(0.06))
            }
        }

        @ViewBuilder private func border(_ shape: RoundedRectangle) -> some View {
            switch kind {
            case .primary: shape.strokeBorder(Palette.limeText.opacity(0.45), lineWidth: 1)
            case .soft: shape.strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
            case .dangerGhost: shape.strokeBorder(Palette.dangerLine.opacity(0.35), lineWidth: 1)
            case .ghost, .danger: EmptyView()
            }
        }
    }

    struct GalleryPrimaryButton: View {
        var title: String
        var symbol: String?
        var size: GalleryButtonSize = .medium

        var body: some View {
            GalleryButton(title: title, symbol: symbol, kind: .primary, size: size)
        }
    }

    struct GalleryButton: View {
        var title: String
        var symbol: String?
        var kind: GalleryButtonKind
        var size: GalleryButtonSize = .large

        var body: some View {
            Button {
            } label: {
                HStack(spacing: 7) {
                    if let symbol { Image(systemName: symbol).font(.system(size: 10, weight: .bold)) }
                    Text(title)
                }
            }
            .buttonStyle(GalleryButtonStyle(kind: kind, size: size))
        }
    }

    struct ButtonsSection: View {
        private let actions = [
            ("calendar", "Schedule"), ("checklist", "Subtasks"), ("note.text", "Notes"), ("bolt.fill", "Make live"),
        ]
        private let controls = [
            ("cup.and.saucer", "Break"), ("note.text", "Notes"), ("pause.fill", "Pause"),
            ("forward.end.fill", "Skip"),
        ]

        var body: some View {
            GallerySection(label: "BUTTONS · HOVER & PRESS ARE LIVE") {
                HStack(spacing: 10) {
                    GalleryPrimaryButton(title: "Start", symbol: "play.fill", size: .large)
                    GalleryButton(title: "Schedule", kind: .soft)
                    GalleryButton(title: "Cancel", kind: .ghost)
                    GalleryButton(title: "Delete all", kind: .danger)
                    GalleryButton(title: "Empty Trash", kind: .dangerGhost)
                }
                HStack(spacing: 10) {
                    GalleryPrimaryButton(title: "sm 28", size: .small)
                    GalleryPrimaryButton(title: "md 34", size: .medium)
                    GalleryPrimaryButton(title: "lg 40", size: .large)
                    GalleryButton(title: "Disabled", kind: .soft, size: .medium).disabled(true)
                    Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1, height: 28).padding(.horizontal, 4)
                    ForEach(actions, id: \.1) { symbol, label in
                        ActionButton(symbol: symbol, label: label, isGo: symbol == "bolt.fill")
                    }
                }
                WeightedHStack(weights: [1, 1, 1, 1, 1], spacing: 6) {
                    ForEach(controls, id: \.1) { symbol, label in
                        ControlTile(symbol: symbol, label: label, isPrimary: false)
                    }
                    ControlTile(symbol: "checkmark", label: "Done", isPrimary: true)
                }
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

    /// The 30 pt `.k-act` icon buttons on a hovered card.
    private struct ActionButton: View {
        var symbol: String
        var label: String
        var isGo: Bool
        @State private var isHovered = false

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
            let lit = isGo && isHovered
            Button {
            } label: {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(lit ? Palette.onAccent : isHovered ? Palette.textPrimary : Palette.textTertiary)
                    .frame(width: 30, height: 30)
                    .background(lit ? Palette.lime : Color.white.opacity(isHovered ? 0.14 : 0.06), in: shape)
                    .overlay(shape.strokeBorder(lit ? Palette.lime : Color.white.opacity(0.08), lineWidth: 1))
                    .shadow(color: lit ? Palette.lime.opacity(0.8) : .clear, radius: 9)
                    .scaleEffect(isHovered ? 1.1 : 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .onHover { hovering in withAnimation(Motion.spring) { isHovered = hovering } }
        }
    }

    /// One 56 pt tile of the control bar (DESIGN_SYSTEM §10.4).
    private struct ControlTile: View {
        var symbol: String
        var label: String
        var isPrimary: Bool

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 15, weight: .semibold))
                Text(label).font(.system(size: 11, weight: isPrimary ? .bold : .semibold))
            }
            .foregroundStyle(isPrimary ? Palette.onAccent : Palette.textBody)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                if isPrimary {
                    shape.fill(
                        LinearGradient(
                            colors: [Palette.teal, Palette.lime], startPoint: .topLeading, endPoint: .bottomTrailing))
                } else {
                    shape.fill(Color.white.opacity(0.045))
                }
            }
            .overlay(shape.strokeBorder(isPrimary ? Palette.limeText.opacity(0.45) : Palette.border, lineWidth: 1))
            .overlay { if isPrimary { Color.clear.sheen(cornerRadius: Radius.tile) } }
            .shadow(color: isPrimary ? Palette.lime.opacity(0.35) : .clear, radius: 12, y: 6)
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
                    Toggle("Pomodoros", isOn: $pomodoros)
                    Toggle("Success sound", isOn: $successSound)
                    Toggle(isOn: $collectFeedback) {
                        Text("Collect feedback")
                            .strikethrough(collectFeedback)
                            .foregroundStyle(collectFeedback ? Palette.textMuted : Palette.textPrimary)
                    }
                    .toggleStyle(.checkbox)
                }
                .toggleStyle(.switch)
                .tint(Palette.green)
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
                chips
                statuses
                WeightedHStack(weights: [1, 1, 1], spacing: 10) {
                    GalleryField(text: $title, placeholder: "Task title", state: .normal)
                    GalleryField(text: $focused, placeholder: "", state: .focused) {
                        GalleryChip(text: "45min", tint: .lime, height: 20)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        GalleryField(text: $clientID, placeholder: "", state: .error)
                        Text("That client ID isn't valid.")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.dangerText)
                    }
                }
            }
        }

        private var modeNote: String {
            switch mode {
            case .onThisMac: "Email never leaves this Mac."
            case .claude: "Claude mode sends each email’s text to Anthropic, using your API key."
            }
        }

        private var chips: some View {
            FlowRow(spacing: 6) {
                GalleryChip(text: "2hr 30min", icon: "clock")
                GalleryChip(text: "Sun 10:00 AM", tint: .blue)
                GalleryChip(text: "Due Oct 10", tint: .amber)
                GalleryChip(text: "Every Friday", tint: .violet)
                GalleryChip(text: "Overdue · 9:00 AM", tint: .red)
                GalleryChip(text: "45min parsed", tint: .lime)
                GalleryChip(text: "Added", tint: .green)
                GalleryChip(text: "Review", tint: .amber)
                GalleryChip(text: "Skipped", tint: .outline)
                GalleryChip(text: "New", tint: .pink)
                GalleryChip(text: "Scanning", tint: .teal)
            }
        }

        private var statuses: some View {
            HStack(spacing: 18) {
                status("Active") { Circle().fill(Palette.green).ping(Palette.green) }
                status("Scanning") { Circle().fill(Palette.teal).ping(Palette.teal) }
                status("Paused") { Circle().fill(Palette.textMuted) }
                status("Needs attention") { Circle().fill(Palette.danger) }
                status("Offline") { Circle().strokeBorder(Palette.textMuted, lineWidth: 1.5) }
            }
            .font(.system(size: 12.5))
            .foregroundStyle(Palette.textTertiary)
        }

        private func status<Dot: View>(_ label: String, @ViewBuilder dot: () -> Dot) -> some View {
            HStack(spacing: 7) {
                dot().frame(width: 7, height: 7)
                Text(label)
            }
        }
    }

    private struct GalleryField<Accessory: View>: View {
        enum FieldState {
            case normal
            case focused
            case error
        }

        @Binding var text: String
        var placeholder: String
        var state: FieldState
        @ViewBuilder var accessory: Accessory

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
            HStack(spacing: 9) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textPrimary)
                accessory
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(state == .focused ? Palette.card : Color.white.opacity(0.04), in: shape)
            .overlay(shape.strokeBorder(borderColor, lineWidth: 1))
            .background(shape.stroke(ringColor, lineWidth: 8))
        }

        private var borderColor: Color {
            switch state {
            case .normal: .white.opacity(0.08)
            case .focused: Palette.teal.opacity(0.6)
            case .error: Palette.danger.opacity(0.7)
            }
        }

        private var ringColor: Color {
            switch state {
            case .normal: .clear
            case .focused: Palette.teal.opacity(0.12)
            case .error: Palette.danger.opacity(0.1)
            }
        }
    }

    extension GalleryField where Accessory == EmptyView {
        init(text: Binding<String>, placeholder: String, state: FieldState) {
            self.init(text: text, placeholder: placeholder, state: state) { EmptyView() }
        }
    }

    /// Wraps children onto new lines like CSS `flex-wrap: wrap`.
    // `SwiftUI.Layout` is spelled out because the app's `Layout` token enum shadows the protocol.
    private struct FlowRow: SwiftUI.Layout {
        var spacing: CGFloat

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
            let width = rows.map(\.width).max() ?? 0
            let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
            return CGSize(width: width, height: height)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            var y = bounds.minY
            for row in arrange(width: bounds.width, subviews: subviews) {
                var x = bounds.minX
                for index in row.indices {
                    let size = subviews[index].sizeThatFits(.unspecified)
                    subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                    x += size.width + spacing
                }
                y += row.height + spacing
            }
        }

        private struct Row {
            var indices: [Int] = []
            var width: CGFloat = 0
            var height: CGFloat = 0
        }

        private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
            var rows = [Row()]
            for index in subviews.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                let current = rows[rows.count - 1]
                let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
                if needed > width && !current.indices.isEmpty {
                    rows.append(Row(indices: [index], width: size.width, height: size.height))
                } else {
                    rows[rows.count - 1].indices.append(index)
                    rows[rows.count - 1].width = needed
                    rows[rows.count - 1].height = max(current.height, size.height)
                }
            }
            return rows
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
