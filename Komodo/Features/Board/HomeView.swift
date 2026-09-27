import SwiftUI

/// The Home window (DESIGN_SYSTEM §12): the sidebar flush beside the Board. The title bar is hidden so the
/// traffic lights sit over the sidebar and the Board's toolbar row runs to the top, as on the canvas. A plain
/// stack instead of `NavigationSplitView`, whose sidebar macOS 26 insets as a floating panel.
struct HomeView: View {
    @Bindable var store: BoardStore
    @AppStorage(SidebarVisibility.key) private var isSidebarVisible = true

    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                SidebarView(store: store)
                    .frame(width: Layout.sidebarIdeal)
                    .transition(.move(edge: .leading))
            }
            BoardView(store: store)
                .inspector(isPresented: isInspectorPresented) {
                    InspectorView(store: store)
                        .inspectorColumnWidth(
                            min: Layout.inspectorMin, ideal: Layout.inspectorIdeal, max: Layout.inspectorMax)
                }
        }
        .animation(Motion.base, value: isSidebarVisible)
        // Esc closes the inspector from anywhere in the window; fields that use Esc themselves handle it first.
        .onExitCommand { store.inspect(nil) }
        .background { shortcuts }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    /// Keys with no visible button: ⌘↑ / ⌘↓ step through tasks in the inspector (DESIGN_SYSTEM §13.5), and ⌘⌥N opens
    /// the live task's notes (FEATURES §4.5).
    private var shortcuts: some View {
        Group {
            Button("Previous task") { store.inspectAdjacent(-1) }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .disabled(store.inspectedTaskID == nil)
            Button("Next task") { store.inspectAdjacent(1) }
                .keyboardShortcut(.downArrow, modifiers: .command)
                .disabled(store.inspectedTaskID == nil)
            Button("Notes") { store.inspect(store.liveTask?.id) }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(store.liveTask == nil)
        }
        .hidden()
    }

    private var isInspectorPresented: Binding<Bool> {
        Binding(get: { store.inspectedTaskID != nil }, set: { if !$0 { store.inspect(nil) } })
    }
}

/// ⌃⌘S shows and hides the sidebar, like the standard sidebar command.
enum SidebarVisibility {
    static let key = "sidebarVisible"
}

struct SidebarCommand: Commands {
    @AppStorage(SidebarVisibility.key) private var isSidebarVisible = true

    var body: some Commands {
        CommandGroup(replacing: .sidebar) {
            Button(isSidebarVisible ? "Hide Sidebar" : "Show Sidebar") { isSidebarVisible.toggle() }
                .keyboardShortcut("s", modifiers: [.control, .command])
        }
    }
}

#Preview("Home") {
    HomeView(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
        .frame(width: 1440, height: 960)
}
