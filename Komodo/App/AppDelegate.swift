import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The delegate owns the panels (ARCHITECTURE §4.1); `KomodoApp` hands it the store once Home appears.
    let focusSurfaces = FocusSurfaceController()
    let alerts = FocusAlerts()
    let settingsWindow = SettingsWindowController()

    private var store: BoardStore?

    /// Called once Home appears with the app's store.
    func attach(_ store: BoardStore) {
        self.store = store
        focusSurfaces.attach(store)
        settingsWindow.attach(store)
        guard store.alerts == nil else { return }
        alerts.install()
        alerts.onResume = { store.endBreak() }
        store.alerts = alerts
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.pauseForQuit()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Only dark values are designed; Light is P2 (DESIGN_SYSTEM §2).
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
}
