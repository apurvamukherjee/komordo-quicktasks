import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The delegate owns the panels (ARCHITECTURE §4.1); `KomodoApp` hands it the store once Home appears.
    let focusSurfaces = FocusSurfaceController()
    let alerts = FocusAlerts()
    let settingsWindow = SettingsWindowController()
    let hotKeys = GlobalHotKeys()

    private var store: BoardStore?

    /// Called once Home appears with the app's store.
    func attach(_ store: BoardStore) {
        self.store = store
        focusSurfaces.attach(store)
        settingsWindow.attach(store)
        guard store.alerts == nil else { return }
        followDockSetting()
        installHotKeys(store)
        alerts.install()
        alerts.onResume = { store.endBreak() }
        alerts.onExtend = { store.extendEstimate(by: 5 * 60) }
        alerts.onDone = { store.completeLive() }
        alerts.onStartNow = { id in store.startNow(id) }
        alerts.onOpen = { id in
            store.showHome()
            store.inspectedTaskID = id
        }
        store.alerts = alerts
    }

    /// Show Komodo in the Dock: off makes Komodo a menu bar app, reachable from its menu bar item.
    private func followDockSetting() {
        guard let store else { return }
        let policy: NSApplication.ActivationPolicy = store.settings.showsInDock ? .regular : .accessory
        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
            // Switching policy hands focus to another app; Settings is where the switch was flipped.
            if !LaunchOptions.capturesQuietly { NSApp.activate() }
        }
        withObservationTracking {
            _ = store.settings.showsInDock
        } onChange: { [weak self] in
            Task { @MainActor in self?.followDockSetting() }
        }
    }

    /// Background captures leave the maintainer's ⌘⇧B, ⌘⇧T and ⌘⇧P alone.
    private func installHotKeys(_ store: BoardStore) {
        guard !LaunchOptions.capturesQuietly else { return }
        hotKeys.onPress = { action in
            switch action {
            case .showKomodo: store.showHome()
            case .togglePanel: store.toggleFloatingTimer()
            case .findTimer: store.locateFloatingTimer()
            }
        }
        hotKeys.install()
        followShortcuts(store)
    }

    private func followShortcuts(_ store: BoardStore) {
        store.shortcutConflicts = hotKeys.register(store.settings)
        withObservationTracking {
            _ = store.settings.shortcuts
        } onChange: { [weak self] in
            Task { @MainActor in self?.followShortcuts(store) }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.pauseForQuit()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Only dark values are designed; Light is P2 (DESIGN_SYSTEM §2).
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
}
