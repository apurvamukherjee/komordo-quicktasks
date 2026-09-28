import SwiftUI

/// The Focus menu (ARCHITECTURE §4.1) with the app shortcuts from FEATURES §4.17. They work wherever Komodo has
/// a key window, the Focus Panel and the floating timer included. ⌘⇧T and ⌘⇧P become global with the menu bar
/// app (System surfaces); until then they need Komodo in front.
struct FocusCommands: Commands {
    var store: BoardStore

    var body: some Commands {
        CommandMenu("Focus") {
            Button(store.focusSurface == .floatingTimer ? "Show Focus Panel" : "Show Floating Timer") {
                store.toggleFloatingTimer()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .disabled(!store.isFocusing && store.focusSurface == nil)
            Button("Find Floating Timer") { store.locateFloatingTimer() }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(store.focusSurface != .floatingTimer)
            Divider()
            let isLive = store.liveTask != nil
            let isRunning = store.liveTask.map { store.focusClock(for: $0).isRunning } ?? false
            Button(isRunning ? "Pause" : "Resume", action: store.togglePause)
                .keyboardShortcut("p", modifiers: [.command, .option])
                .disabled(!isLive)
            Button("Start Break", action: store.takeBreak)
                .keyboardShortcut("b", modifiers: [.command, .option])
                .disabled(!isLive)
            Button("Skip", action: store.skip)
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(!isLive)
            Button("Done", action: store.completeLive)
                .keyboardShortcut("f", modifiers: [.command, .option])
                .disabled(!isLive)
        }
    }
}
