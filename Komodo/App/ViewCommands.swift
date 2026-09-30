import SwiftUI

/// The View menu's first items (DESIGN_SYSTEM §14.3): Board ⌘1 and Reports ⌘2, above the standard sidebar item.
/// Both bring Home forward first, since either page lives there.
struct ViewCommands: Commands {
    var store: BoardStore

    var body: some Commands {
        CommandGroup(before: .sidebar) {
            Button("Board") {
                store.showHome()
                store.showBoard()
            }
            .keyboardShortcut("1", modifiers: .command)
            Button("Reports") {
                store.showHome()
                store.showReports()
            }
            .keyboardShortcut("2", modifiers: .command)
            Divider()
        }
    }
}
