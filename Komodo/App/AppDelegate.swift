import AppKit
import KomodoCore
import OSLog
import notify

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The delegate owns the panels (ARCHITECTURE §4.1); `KomodoApp` hands it the store once Home appears.
    let focusSurfaces = FocusSurfaceController()
    let alerts = FocusAlerts()
    let settingsWindow = SettingsWindowController()
    let hotKeys = GlobalHotKeys()
    let calendarSync = CalendarSync()

    private var store: BoardStore?
    /// A `komodo://start` that arrived before Home handed over the store, as when it launched Komodo.
    private var pendingStart: String?
    private var outsideWrites: Int32 = 0
    private let backupScheduler = NSBackgroundActivityScheduler(identifier: "app.komodo.Komodo.backup")

    /// Called once Home appears with the app's store.
    func attach(_ store: BoardStore) {
        self.store = store
        focusSurfaces.attach(store)
        settingsWindow.attach(store)
        guard store.alerts == nil else { return }
        watchForNewDay(store)
        watchForSleep(store)
        scheduleBackups(store)
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
        watchForOutsideWrites(store)
        calendarSync.attach(store)
        if let id = pendingStart {
            pendingStart = nil
            start(id, in: store)
        }
    }

    // MARK: Local MCP server

    /// `komodo-mcp` posts after each write; the app takes the new rows without resetting anything on screen.
    private func watchForOutsideWrites(_ store: BoardStore) {
        let status = notify_register_dispatch(BoardChange.darwinNotification, &outsideWrites, .main) { _ in
            Task { @MainActor in store.absorbOutsideChanges() }
        }
        if status != NOTIFY_STATUS_OK {
            Logger(subsystem: "app.komodo.Komodo", category: "mcp").error("Couldn't watch for MCP writes: \(status)")
        }
    }

    /// `komodo://start?task=<id>` (ARCHITECTURE §4.1), which `start_focus` opens: the task goes live in Focus mode.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "komodo" && url.host() == "start" {
            guard
                let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
                    .first(where: { $0.name == "task" })?.value
            else { continue }
            if let store { start(id, in: store) } else { pendingStart = id }
        }
    }

    private func start(_ id: String, in store: BoardStore) {
        // The helper may have just added the task, ahead of the notification.
        store.absorbOutsideChanges()
        guard store.tasks.contains(where: { $0.id == id && !$0.isDone }) else { return }
        store.startNow(id)
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

    /// ARCHITECTURE §4.4's daily backup: a check a minute after launch, so it lands within FEATURES §4.21's five
    /// minutes, then hourly while Komodo runs. Each check backs up only when today's zip isn't there yet.
    private func scheduleBackups(_ store: BoardStore) {
        guard store.database != nil, !LaunchOptions.capturesQuietly else { return }
        Task {
            // Cancelled only if the app quits first, when there's nothing left to back up for.
            guard (try? await Task.sleep(for: .seconds(60))) != nil else { return }
            await store.backUpIfDue()
        }
        backupScheduler.repeats = true
        backupScheduler.interval = 60 * 60
        backupScheduler.tolerance = 10 * 60
        backupScheduler.qualityOfService = .utility
        backupScheduler.schedule { completion in
            Task { @MainActor in
                await store.backUpIfDue()
                completion(.finished)
            }
        }
    }

    /// ARCHITECTURE §4.4's day rollover: the calendar day changing, the time zone changing, and waking up.
    private func watchForNewDay(_ store: BoardStore) {
        let names: [(NotificationCenter, Notification.Name)] = [
            (.default, .NSCalendarDayChanged),
            (.default, .NSSystemTimeZoneDidChange),
            (NSWorkspace.shared.notificationCenter, NSWorkspace.didWakeNotification),
        ]
        for (center, name) in names {
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { store.dayMayHaveChanged() }
            }
        }
    }

    /// ARCHITECTURE §4.3's sleep question: sleep notes the time, and waking asks about a long gap.
    private func watchForSleep(_ store: BoardStore) {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { store.willSleep() }
        }
        center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { store.didWake() }
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
