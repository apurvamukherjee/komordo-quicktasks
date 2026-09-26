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
        }
        .animation(Motion.base, value: isSidebarVisible)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
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
