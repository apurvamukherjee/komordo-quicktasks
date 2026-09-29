import KomodoCore
import SwiftUI

/// ⌘F search and commands (DESIGN_SYSTEM §13.7, CommandPalette.png): a 560 pt sheet near the top of the Home
/// window. Typing searches titles, notes and subtasks in every list, grouped by list; `>` switches to commands.
/// ↑↓ move, Return opens, ⌘Return starts now, Esc closes.
struct CommandPalette: View {
    var store: BoardStore
    var close: () -> Void

    @State private var query = LaunchOptions.paletteQuery ?? ""
    @State private var selection = 0
    @FocusState private var isFocused: Bool

    private var isCommandMode: Bool { query.hasPrefix(">") }
    private var needle: String { query.trimmingCharacters(in: .whitespaces) }

    /// Hits grouped by list in the sidebar's order, flattened in the order they're drawn so ↑↓ follow the eye.
    private var groups: [(list: TaskList, hits: [TaskSearch.Hit])] {
        let hits = TaskSearch.hits(for: needle, in: store.tasks)
        return store.lists.compactMap { list in
            let inList = hits.filter { hit in store.tasks.first { $0.id == hit.taskID }?.listID == list.id }
            return inList.isEmpty ? nil : (list, inList)
        }
    }

    private var rows: [PaletteRow] {
        if isCommandMode {
            let filter = query.dropFirst().trimmingCharacters(in: .whitespaces)
            return PaletteCommand.all(store: store)
                .filter { filter.isEmpty || $0.title.localizedStandardContains(filter) }
                .map(PaletteRow.command)
        }
        guard !needle.isEmpty else { return [] }
        let hits = groups.flatMap(\.hits).map(PaletteRow.task)
        return hits.isEmpty ? [.create] : hits
    }

    var body: some View {
        let rows = self.rows
        VStack(spacing: 0) {
            searchRow
            if !rows.isEmpty {
                Divider().overlay(Palette.border)
                ScrollView { content(rows) }
                    .scrollIndicators(.never)
                    .frame(maxHeight: 292)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider().overlay(Palette.border)
            footer(rows)
        }
        .frame(width: Layout.commandPaletteWidth)
        .popoverSurface()
        .onAppear { isFocused = true }
        .onChange(of: query) { selection = 0 }
        .background {
            // ⌘Return, whichever row is selected.
            Button("Start now") { startNow(rows) }
                .keyboardShortcut(.return, modifiers: .command)
                .hidden()
        }
    }

    // MARK: Search

    private var searchRow: some View {
        HStack(spacing: Space.s3) {
            Image(systemName: isCommandMode ? "apple.terminal" : "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isCommandMode ? Palette.limeText : Palette.teal)
            TextField("Search", text: $query, prompt: Text("Search tasks, notes, subtasks… or > for commands"))
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .medium))
                .tracking(-0.17)
                .foregroundStyle(Palette.textPrimary)
                .focused($isFocused)
                .focusEffectDisabled()
                .onSubmit { run(rows) }
                .onExitCommand(perform: close)
                .onKeyPress(keys: [.upArrow, .downArrow]) { press in
                    move(by: press.key == .upArrow ? -1 : 1)
                    return .handled
                }
                .onKeyPress(.delete) {
                    // ⌫ on a bare ">" goes back to search, as the footer says.
                    guard query == ">" else { return .ignored }
                    query = ""
                    return .handled
                }
            if isCommandMode {
                Chip("Commands", tint: .lime, size: .compact)
            } else if !query.isEmpty {
                Button("Clear", systemImage: "xmark") { query = "" }
                    .buttonStyle(.icon(.compact))
            }
            KeyCap("esc")
        }
        .padding(.leading, 18)
        .padding(.trailing, Space.s4)
        .frame(height: 54)
    }

    // MARK: Rows

    @ViewBuilder private func content(_ rows: [PaletteRow]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if isCommandMode {
                header("COMMANDS")
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if case .command(let command) = row { commandRow(command, index: index) }
                }
            } else if rows.first == .create {
                emptyState
                createRow(index: 0)
            } else {
                let offsets = groupOffsets
                ForEach(Array(groups.enumerated()), id: \.element.list.id) { groupIndex, group in
                    header(group.list.name.uppercased())
                    ForEach(Array(group.hits.enumerated()), id: \.element.taskID) { index, hit in
                        taskRow(hit, index: offsets[groupIndex] + index)
                    }
                }
            }
        }
        .padding(6)
    }

    /// Where each group's rows start in the flat list.
    private var groupOffsets: [Int] {
        var offsets: [Int] = []
        var total = 0
        for group in groups {
            offsets.append(total)
            total += group.hits.count
        }
        return offsets
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .bold))
            .tracking(0.84)
            .foregroundStyle(Palette.textMuted)
            .padding(.leading, 14)
            .padding(.trailing, Space.s3)
            .padding(.top, 10)
            .padding(.bottom, 5)
    }

    private func taskRow(_ hit: TaskSearch.Hit, index: Int) -> some View {
        let task = store.tasks.first { $0.id == hit.taskID }
        let list = task.flatMap { store.list(for: $0) }
        return PaletteRowFrame(
            isSelected: selection == index, onHover: { selection = index }, action: { open(hit.taskID) },
            content: {
                StatusBox(isDone: task?.isDone ?? false)
                VStack(alignment: .leading, spacing: 3) {
                    Text(highlighted(task?.title ?? "", done: task?.isDone ?? false))
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(
                            task?.isDone == true
                                ? Palette.textMuted : selection == index ? Palette.textPrimary : Palette.textBody
                        )
                        .strikethrough(task?.isDone == true, color: Palette.textMuted.opacity(0.8))
                        .lineLimit(1)
                    switch hit.place {
                    case .title: EmptyView()
                    case .notes(let snippet): snippetText("Notes · ", snippet)
                    case .subtask(let title): snippetText("Subtask · ", title)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let list {
                    HStack(spacing: 6) {
                        ListBadge(letter: list.letter, color: ListColor(rawValue: list.color) ?? .lime, side: 18)
                        Text(list.name).lineLimit(1)
                    }
                    .frame(width: 100, alignment: .leading)
                }
                Text(task.map(meta) ?? "")
                    .lineLimit(1)
                    .frame(width: 112, alignment: .trailing)
            })
    }

    private func snippetText(_ prefix: String, _ text: String) -> some View {
        (Text(prefix) + Text(highlighted(text, done: false)))
            .font(.system(size: 11.5))
            .foregroundStyle(Palette.textMuted)
            .lineLimit(1)
    }

    /// The match in lime on a 16% lime fill (row anatomy on the canvas); dimmer on a done task.
    private func highlighted(_ text: String, done: Bool) -> AttributedString {
        var string = AttributedString(text)
        if let range = string.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) {
            string[range].foregroundColor = done ? Palette.limeText.opacity(0.7) : Palette.limeText
            string[range].backgroundColor = Palette.lime.opacity(done ? 0.08 : 0.16)
        }
        return string
    }

    /// "Today · 1hr", "Backlog · 3hr" or "Done · Sep 12".
    private func meta(_ task: TaskItem) -> String {
        if let completed = task.completedAt {
            return "Done · \(completed.formatted(.dateTime.month(.abbreviated).day()))"
        }
        let column = BoardStore.title(for: task.column(in: store.week))
        return [column, task.estimate.map(DurationFormat.short)].compactMap { $0 }.joined(separator: " · ")
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.tealText)
                .frame(width: 44, height: 44)
                .background(
                    RadialGradient(
                        colors: [Palette.teal.opacity(0.18), Palette.teal.opacity(0.04)], center: .center,
                        startRadius: 0, endRadius: 22),
                    in: Circle()
                )
                .overlay(Circle().strokeBorder(Palette.teal.opacity(0.22), lineWidth: 1))
                .shadow(color: Palette.teal.opacity(0.3), radius: 15)
                .padding(.bottom, 6)
            Text("No tasks match '\(needle)'.")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            Text("Searched titles, notes and subtasks in every list, including Done.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.textSecondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.s5)
        .padding(.top, 22)
        .padding(.bottom, Space.s4)
    }

    private var createList: TaskList? {
        store.lists.first { $0.id == (store.selectedListID ?? store.lastListID) } ?? store.lists.first
    }

    private func createRow(index: Int) -> some View {
        PaletteRowFrame(
            isSelected: selection == index, onHover: { selection = index }, action: { create(andStart: false) },
            content: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.limeText)
                    .frame(width: 26, height: 26)
                    .background(Palette.lime.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text("Create task \"\(needle)\"")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let list = createList {
                    HStack(spacing: 6) {
                        ListBadge(letter: list.letter, color: ListColor(rawValue: list.color) ?? .lime, side: 18)
                        Text("\(list.name) · Today").lineLimit(1)
                    }
                }
            })
    }

    private func commandRow(_ command: PaletteCommand, index: Int) -> some View {
        PaletteRowFrame(
            isSelected: selection == index, onHover: { selection = index }, action: { run(command) },
            content: {
                Image(systemName: command.symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(command.glyph)
                    .frame(width: 26, height: 26)
                    .background(command.tint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(command.title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let detail = command.detail {
                    Text(detail).lineLimit(1)
                }
                if let keys = command.keys { KeyCap(keys) }
            }
        )
        .opacity(command.isEnabled ? 1 : 0.4)
        .help(command.isEnabled ? "" : "Arrives in a later milestone")
    }

    // MARK: Footer

    private func footer(_ rows: [PaletteRow]) -> some View {
        HStack(spacing: 14) {
            if isCommandMode {
                key("↑↓", "move")
                key("↵", "run")
                key("⌫", "back to search")
            } else if rows.first == .create {
                key("↵", "create")
                key("⌘↵", "create & start")
            } else {
                key("↑↓", "move")
                key("↵", "open")
                key("⌘↵", "start now")
            }
            key("esc", "close")
            Spacer()
            Text(count(rows)).monospacedDigit()
        }
        .font(.system(size: 11.5))
        .foregroundStyle(Palette.textMuted)
        .padding(.leading, Space.s4)
        .padding(.trailing, 14)
        .frame(height: 40)
    }

    private func key(_ keys: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            KeyCap(keys)
            Text(label)
        }
    }

    private func count(_ rows: [PaletteRow]) -> String {
        if isCommandMode { return rows.count == 1 ? "1 command" : "\(rows.count) commands" }
        let results = rows.first == .create ? 0 : rows.count
        return results == 1 ? "1 result" : "\(results) results"
    }

    // MARK: Actions

    private func move(by offset: Int) {
        let count = rows.count
        guard count > 0 else { return }
        selection = (selection + offset + count) % count
    }

    private func run(_ rows: [PaletteRow]) {
        guard rows.indices.contains(selection) else { return }
        switch rows[selection] {
        case .task(let hit): open(hit.taskID)
        case .create: create(andStart: false)
        case .command(let command): run(command)
        }
    }

    private func startNow(_ rows: [PaletteRow]) {
        guard rows.indices.contains(selection) else { return }
        switch rows[selection] {
        case .task(let hit):
            guard store.tasks.first(where: { $0.id == hit.taskID })?.isDone == false else { return }
            store.startNow(hit.taskID)
            close()
        case .create: create(andStart: true)
        case .command(let command): run(command)
        }
    }

    private func open(_ id: String) {
        store.inspect(id)
        close()
    }

    private func create(andStart: Bool) {
        guard !needle.isEmpty else { return }
        if andStart {
            store.addAndStart(needle, listID: createList?.id)
            if store.focusSurface == nil { store.focusSurface = .panel }
        } else {
            store.addTask(needle, to: .today, listID: createList?.id)
        }
        close()
    }

    private func run(_ command: PaletteCommand) {
        guard command.isEnabled else { return }
        close()
        command.perform()
    }
}

/// One selectable line in the palette.
private enum PaletteRow: Equatable {
    case task(TaskSearch.Hit)
    case create
    case command(PaletteCommand)
}

/// DESIGN_SYSTEM §13.7's commands. Backup and Gmail show but wait for their milestones.
private struct PaletteCommand: Equatable {
    var title: String
    var symbol: String
    var tint: Color
    var glyph: Color
    var detail: String?
    var keys: String?
    var isEnabled = true
    var perform: @MainActor () -> Void = {}

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.title == rhs.title && lhs.isEnabled == rhs.isEnabled }

    @MainActor static func all(store: BoardStore) -> [PaletteCommand] {
        [
            PaletteCommand(
                title: "New Task", symbol: "plus", tint: Palette.lime.opacity(0.14), glyph: Palette.limeText,
                keys: "⌘⌥T"
            ) { store.isQuickAddOpen = true },
            PaletteCommand(
                title: "Start", symbol: "play.fill", tint: Palette.lime, glyph: Palette.onAccent,
                detail: "Focus mode · top of the queue", isEnabled: !store.isFocusing && !store.layout.upNext.isEmpty
            ) { store.start() },
            PaletteCommand(
                title: "Export Backup", symbol: "archivebox", tint: Palette.green.opacity(0.14),
                glyph: Palette.greenText, isEnabled: false),
            PaletteCommand(
                title: "Scan Gmail Now", symbol: "envelope", tint: Palette.danger.opacity(0.14), glyph: Palette.redText,
                isEnabled: false),
            PaletteCommand(
                title: "Settings", symbol: "slider.horizontal.3", tint: Color.white.opacity(0.06),
                glyph: Palette.textTertiary, keys: "⌘,"
            ) { store.showSettings() },
        ]
    }
}

/// `.cp-row`: 44 pt, radius 10; the selected row gets a faint fill and a 2 pt glowing teal bar on the left, and
/// hovering moves the selection.
private struct PaletteRowFrame<Content: View>: View {
    var isSelected: Bool
    var onHover: () -> Void
    var action: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 10) {
            content
            KeyCap("↵").opacity(isSelected ? 1 : 0).frame(width: 22, alignment: .trailing)
        }
        .font(.system(size: 12))
        .foregroundStyle(Palette.textSecondary)
        .padding(.vertical, 7)
        .padding(.leading, 14)
        .padding(.trailing, Space.s3)
        .frame(minHeight: 44)
        .background(
            Color.white.opacity(isSelected ? 0.075 : 0), in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule().fill(Palette.teal).frame(width: 2).padding(.vertical, 9)
                    .shadow(color: Palette.teal.opacity(0.9), radius: 5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onHover { if $0 { onHover() } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { action() }
    }
}

/// The open or done box at the start of a task row.
private struct StatusBox: View {
    var isDone: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)
        ZStack {
            if isDone {
                shape.fill(Palette.lime)
                Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(Palette.onAccent)
            } else {
                shape.strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)
            }
        }
        .frame(width: 16, height: 16)
    }
}

#Preview("Command palette") {
    CommandPalette(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)) {}
        .padding(Space.s8)
        .background(Palette.bg)
}
