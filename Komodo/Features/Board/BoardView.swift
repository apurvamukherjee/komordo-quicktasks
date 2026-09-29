import KomodoCore
import SwiftUI

/// The Board, single list or All lists (DESIGN_SYSTEM §13.2–13.3): toolbar, header, and the three columns
/// weighted 1 : 1.06 : 1.52 by time temperature.
struct BoardView: View {
    @Bindable var store: BoardStore
    @FocusState private var focusedTask: String?
    @AppStorage(SidebarVisibility.key) private var isSidebarVisible = true

    var body: some View {
        VStack(spacing: 0) {
            BoardToolbar(store: store)
                // Clears the traffic lights when the sidebar is hidden.
                .padding(.leading, isSidebarVisible ? 0 : 60)
            BoardHeader(store: store)
            WeightedHStack(weights: Layout.columnWeights, spacing: Space.columnGutter) {
                BoardColumnView(store: store, bucket: .backlog, focusedTask: $focusedTask)
                BoardColumnView(store: store, bucket: .week, focusedTask: $focusedTask)
                TodayStageView(store: store, focusedTask: $focusedTask)
            }
            .padding(.horizontal, Space.s5)
            .padding(.bottom, Space.s5)
        }
        .background {
            ZStack {
                Palette.bg
                EllipticalGradient(
                    colors: [Palette.teal.opacity(0.06), .clear], center: UnitPoint(x: 0.85, y: -0.1),
                    startRadiusFraction: 0, endRadiusFraction: 0.75)
            }
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            if store.isQuickAddOpen {
                QuickAddPanel(store: store) { store.isQuickAddOpen = false }
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .offset(y: -8)))
            }
        }
        .overlay(alignment: .top) {
            if store.isPaletteOpen {
                ZStack(alignment: .top) {
                    // The canvas dims the window behind the sheet; a click there closes it.
                    Color.black.opacity(0.45)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                        .onTapGesture { store.isPaletteOpen = false }
                    CommandPalette(store: store) { store.isPaletteOpen = false }
                        .padding(.top, 36)
                }
                .transition(.opacity)
            }
        }
        .animation(Motion.base, value: store.isQuickAddOpen)
        .animation(Motion.base, value: store.isPaletteOpen)
        .toastOverlay(store.toasts)
    }
}

struct BoardToolbar: View {
    @Bindable var store: BoardStore

    var body: some View {
        HStack(spacing: Space.s3) {
            listPicker
            searchButton
                .frame(maxWidth: 440)
            Spacer(minLength: Space.s3)
            if store.isPomodoroOn {
                Label(
                    "Pomodoro \(Int(store.sprintLength / 60)) / \(Int(store.breakLength / 60))", systemImage: "timer"
                )
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.pinkText)
                .padding(.horizontal, Space.s3)
                .frame(height: 34)
                .background(Palette.pink.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.control).strokeBorder(Palette.pink.opacity(0.22))
                )
                .fixedSize()
            }
            Button(action: store.toggleFloatingTimer) {
                HStack(spacing: 7) {
                    Image(systemName: "pip.enter")
                    Text("⌘⇧T").font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Palette.textMuted)
                }
            }
            .buttonStyle(.komodo(.secondary))
            .disabled(!store.isFocusing)
            .help(store.isFocusing ? "Floating timer ⌘⇧T" : "Start Focus mode to use the floating timer")
            Button("Start", systemImage: "play.fill", action: store.start)
                .buttonStyle(.komodo(.primary))
                .disabled(!canStart)
                .help(startHelp)
                // ⌘⇧B brings Komodo forward and Return starts (FEATURES §4.8).
                .keyboardShortcut(.defaultAction)
                .popover(isPresented: $store.showsStartTip, arrowEdge: .bottom) { StartTip(store: store) }
        }
        .padding(.leading, Space.s6)
        .padding(.trailing, 22)
        .frame(height: 62)
    }

    private var canStart: Bool { !store.isFocusing && !store.layout.upNext.isEmpty }

    private var startHelp: String {
        if store.isFocusing { return "Focus mode is on" }
        return store.layout.upNext.isEmpty ? "Add a task to Today" : "Start ↵"
    }

    /// Looks like the search field it replaced, and opens the palette (DESIGN_SYSTEM §13.7).
    private var searchButton: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        return Button {
            store.isPaletteOpen = true
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.textMuted)
                Text("Search tasks, notes, subtasks…")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textMuted)
                    .lineLimit(1)
                Spacer(minLength: 0)
                KeyCap("⌘F")
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Color.white.opacity(0.04), in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .help("Search ⌘F")
    }

    private var listPicker: some View {
        Menu {
            Button("All lists") { store.showList(nil) }
            Divider()
            ForEach(store.lists) { list in
                Button(list.name) { store.showList(list.id) }
            }
        } label: {
            HStack(spacing: Space.s2) {
                if let list = store.selectedList {
                    ListBadge(letter: list.letter, color: ListColor(rawValue: list.color) ?? .lime, side: 20)
                    Text(list.name)
                } else {
                    Image(systemName: "square.grid.2x2")
                    Text("All lists")
                }
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(
                    Palette.textMuted)
            }
            .font(.system(size: 13.5, weight: .semibold))
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        // Launch focus lands here; its system ring would outline the picker before anyone has typed.
        .focusEffectDisabled()
        .buttonStyle(.komodo(.secondary))
        .fixedSize()
    }
}

struct BoardHeader: View {
    @Bindable var store: BoardStore

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: Space.s3) {
                    Text(store.selectedList?.name ?? "All lists")
                        .font(Typography.display)
                        .tracking(Typography.Tracking.display)
                        .foregroundStyle(Palette.textPrimary)
                    Text("\(store.openCount(listID: store.selectedListID)) open")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Palette.limeText)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(Palette.lime.opacity(0.12), in: Capsule())
                }
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Picker("View", selection: allListsBinding) {
                Text("Board").tag(false)
                Text("All lists").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        .padding(.horizontal, Space.s6)
        .padding(.top, 2)
        .padding(.bottom, 18)
    }

    private var allListsBinding: Binding<Bool> {
        Binding(
            get: { store.selectedListID == nil },
            set: { $0 ? store.showList(nil) : store.showBoard() })
    }

    /// "Saturday, Sep 26 · 6hr 30min planned today · fits your day with 1hr 10min to spare" (Main.png), measured
    /// from when the queue should end to the workday's end.
    private var subtitle: String {
        let layout = store.layout
        let planned = (layout.openToday + layout.doneToday).reduce(0) { $0 + ($1.estimate ?? 0) }
        let date = store.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        let summary = "\(date) · \(DurationFormat.short(planned)) planned today"
        guard !layout.openToday.isEmpty else { return summary }
        let workdayEnd = store.today.startOfDay(in: store.calendar).addingTimeInterval(
            TimeInterval(store.workdayEnd * 60))
        let spare = workdayEnd.timeIntervalSince(store.dayPlan().endsAround)
        return spare >= 0
            ? "\(summary) · fits your day with \(DurationFormat.short(spare)) to spare"
            : "\(summary) · runs \(DurationFormat.short(-spare)) past your workday"
    }
}

#Preview("Board") {
    BoardView(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
        .frame(width: 1192, height: 960)
}

/// Onboarding's last step (Onboarding.png ⑦): a tip pointing at Start once the sheet closes with tasks in Today.
private struct StartTip: View {
    var store: BoardStore

    var body: some View {
        HStack(spacing: Space.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Press Start. Your first task goes live.")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text("The timer follows you in a floating pill.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.textSecondary)
            }
            .fixedSize()
            Button("Got it") { store.showsStartTip = false }
                .buttonStyle(.komodo(.ghost, size: .small))
        }
        .padding(.leading, 14)
        .padding(.trailing, Space.s3)
        .padding(.vertical, 10)
        .preferredColorScheme(.dark)
    }
}
