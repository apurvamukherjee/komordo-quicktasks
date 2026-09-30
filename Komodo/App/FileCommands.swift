import SwiftUI

/// The File menu (DESIGN_SYSTEM §14.3): New Task, New List, then the backup items. Close Window stays standard.
/// Each one brings Home forward first, since quick add and the list sheet show over it.
struct FileCommands: Commands {
    var store: BoardStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Task") {
                store.showHome()
                store.isQuickAddOpen = true
            }
            .keyboardShortcut("t", modifiers: [.command, .option])
            Button("New List") {
                store.showHome()
                store.listSheet = .create
            }
        }
        CommandGroup(replacing: .importExport) {
            Button("Export Backup…", action: store.chooseExportDestination)
                .disabled(store.database == nil || store.isExporting)
            // Restore lives on the Data & backup page, with its file picker and confirm.
            Button("Restore from Backup…") { store.showSettings(.data) }
        }
    }
}
