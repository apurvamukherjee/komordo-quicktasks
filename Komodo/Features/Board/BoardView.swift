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
        .animation(Motion.base, value: store.isQuickAddOpen)
        .toastOverlay(store.toasts)
    }
}

struct BoardToolbar: View {
    @Bindable var store: BoardStore

    var body: some View {
        HStack(spacing: Space.s3) {
            listPicker
            KomodoTextField(
                placeholder: "Search tasks, notes, subtasks…", text: $store.searchText, variant: .search,
                density: .toolbar
            ) {
                KeyCap("⌘F")
            }
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
            Button {
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "pip.enter")
                    Text("⌘⇧T").font(.system(size: 10.5, design: .monospaced)).foregroundStyle(Palette.textMuted)
                }
            }
            .buttonStyle(.komodo(.secondary))
            .disabled(true)
            .help("The floating timer arrives with Focus mode")
            Button("Start", systemImage: "play.fill", action: store.start)
                .buttonStyle(.komodo(.primary))
                .disabled(!canStart)
                .help(startHelp)
                // ⌘⇧B brings Komodo forward and Return starts (FEATURES §4.8).
                .keyboardShortcut(.defaultAction)
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

    /// "Saturday, Sep 26 · 6hr 30min planned today".
    private var subtitle: String {
        let layout = store.layout
        let planned = (layout.openToday + layout.doneToday).reduce(0) { $0 + ($1.estimate ?? 0) }
        let date = store.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
        return "\(date) · \(DurationFormat.short(planned)) planned today"
    }
}

#Preview("Board") {
    BoardView(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
        .frame(width: 1192, height: 960)
}
