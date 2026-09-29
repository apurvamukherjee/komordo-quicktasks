import KomodoCore
import SwiftUI

/// ⌘⌥T quick add (DESIGN_SYSTEM §13.4, BoardStates ②): a small panel at the top of the window. The trailing
/// estimate in the title shows as a lime chip; Return adds and stays open for the next one, ⌘Return adds and
/// starts it, Esc closes.
struct QuickAddPanel: View {
    var store: BoardStore
    var close: () -> Void

    @State private var title = ""
    @State private var preset: TimeInterval?
    @State private var bucket = Bucket.today
    @State private var listID: String?
    @FocusState private var isFocused: Bool

    private var parsed: EstimateParser.Result { EstimateParser.parse(title) }
    private var estimate: TimeInterval? { preset ?? parsed.estimate }
    private var list: TaskList? {
        store.lists.first { $0.id == (listID ?? store.selectedListID ?? store.lists.first?.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: Space.s3) {
                titleRow
                controls
            }
            .padding(14)
            Divider().overlay(Palette.border)
            footer
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .frame(width: 560)
        .popoverSurface(tint: SpotlightTint.today)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .strokeBorder(Palette.teal.opacity(0.35), lineWidth: 1)
        )
        .onAppear { isFocused = true }
        .onExitCommand(perform: close)
    }

    private var titleRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.limeText)
            TextField(
                "Task title", text: $title,
                prompt: Text("Add a task to \(BoardStore.title(for: bucket))… try “Write spec 45m”")
                    .foregroundStyle(Palette.textMuted)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Palette.textPrimary)
            .focused($isFocused)
            .focusEffectDisabled()
            .onSubmit { add(andStart: false) }
            if let estimate {
                Chip(DurationFormat.short(estimate), tint: .lime, icon: "clock")
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(height: 30)
        .animation(Motion.fast, value: estimate)
    }

    private var controls: some View {
        HStack(spacing: 6) {
            ForEach(store.settings.quickPresets, id: \.self) { seconds in
                Button(DurationFormat.compact(seconds)) { preset = preset == seconds ? nil : seconds }
                    .buttonStyle(.presetChip)
                    .overlay {
                        if preset == seconds {
                            RoundedRectangle(cornerRadius: 7).strokeBorder(Palette.lime.opacity(0.6))
                        }
                    }
            }
            Spacer()
            listMenu
            bucketMenu
            Button("Add", systemImage: "return") { add(andStart: false) }
                .buttonStyle(.komodo(.primary, size: .small))
                .disabled(parsed.title.isEmpty)
            Button("Add and start") { add(andStart: true) }
                .keyboardShortcut(.return, modifiers: .command)
                .hidden()
                .frame(width: 0, height: 0)
        }
    }

    private var listMenu: some View {
        Menu {
            ForEach(store.lists) { list in
                Button(list.name) { listID = list.id }
            }
        } label: {
            InspectorValue {
                if let list {
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

    private var bucketMenu: some View {
        Menu {
            ForEach([Bucket.today, .week, .backlog], id: \.self) { bucket in
                Button(BoardStore.title(for: bucket)) { self.bucket = bucket }
            }
        } label: {
            InspectorValue {
                Image(systemName: symbol(for: bucket)).font(.system(size: 11, weight: .semibold))
                Text(BoardStore.title(for: bucket))
                Chevron()
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Column")
    }

    /// Creates “Write launch email” · EST 00:45, and the keys.
    private var footer: some View {
        HStack(spacing: 6) {
            Group {
                if parsed.title.isEmpty {
                    Text("A trailing time like “45m” sets the estimate.")
                } else {
                    Text("Creates ") + Text("“\(parsed.title)”").bold().foregroundStyle(Palette.textPrimary)
                        + Text(estimate.map { " · EST \(DurationFormat.hoursMinutes($0))" } ?? "")
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(Palette.textMuted)
            .lineLimit(1)
            Spacer()
            KeyCap("⌘↵")
            Text("add & start").font(.system(size: 11)).foregroundStyle(Palette.textMuted)
            Text("·").foregroundStyle(Palette.textMuted)
            KeyCap("esc")
            Text("close").font(.system(size: 11)).foregroundStyle(Palette.textMuted)
        }
    }

    private func symbol(for bucket: Bucket) -> String {
        switch bucket {
        case .today: "sun.max"
        case .week: "calendar"
        case .backlog: "moon"
        }
    }

    private func add(andStart: Bool) {
        guard !parsed.title.isEmpty else { return }
        if andStart {
            store.addAndStart(title, listID: list?.id, estimate: preset)
            close()
        } else {
            store.addTask(title, to: bucket, listID: list?.id, estimate: preset)
            title = ""
            preset = nil
        }
    }
}

#Preview("Quick add") {
    QuickAddPanel(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)) {}
        .padding(Space.s8)
        .background(Palette.bg)
}
