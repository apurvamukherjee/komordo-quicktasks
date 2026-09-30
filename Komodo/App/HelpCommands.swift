import SwiftUI

/// The Help menu (DESIGN_SYSTEM §14.3): Keyboard Shortcuts opens Settings on its page, and Save Diagnostics… is
/// About's. macOS keeps the search field at the top.
struct HelpCommands: Commands {
    var store: BoardStore

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("Keyboard Shortcuts") { store.showSettings(.shortcuts) }
            Button("Save Diagnostics…", action: store.saveDiagnostics)
        }
    }
}
