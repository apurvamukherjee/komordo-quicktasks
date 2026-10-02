import AppKit
import SwiftUI

/// Shows Focus mode's surfaces (ARCHITECTURE §4.1) as the store asks: the docked Focus Panel, 340 pt wide and
/// as tall as the screen's visible frame on the edge Quick Settings picks, or the floating timer. While either
/// is up the Home window steps aside, and it comes back when Focus mode returns Home (FEATURES §4.8).
@MainActor final class FocusSurfaceController {
    private var store: BoardStore?
    private var panel: NSPanel?
    private var timer: FloatingTimerPanel?
    private var setAside: [NSWindow] = []
    private var isAside = false

    func attach(_ store: BoardStore) {
        guard self.store == nil else { return }
        self.store = store
        sync()
        observe()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.dock()
                self?.timer?.place()
            }
        }
    }

    /// Observation fires once per registration, so each change re-registers after syncing.
    private func observe() {
        guard let store else { return }
        withObservationTracking {
            _ = store.focusSurface
            _ = store.panelSide
            _ = store.settings.panelScreen
            _ = store.settings.floatsAboveFullScreen
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.sync()
                self?.observe()
            }
        }
    }

    private func sync() {
        guard let store else { return }
        setHomeAside(store.focusSurface != nil)
        if store.focusSurface == .panel { showPanel(store) } else { panel?.orderOut(nil) }
        if store.focusSurface == .floatingTimer { showTimer(store) } else { timer?.hide() }
    }

    private func showTimer(_ store: BoardStore) {
        let timer = self.timer ?? FloatingTimerPanel(store: store)
        self.timer = timer
        guard !timer.window.isVisible else { return }
        timer.show()
    }

    private func setHomeAside(_ aside: Bool) {
        guard aside != isAside else { return }
        isAside = aside
        if aside {
            setAside = NSApp.windows.filter { $0.isVisible && $0.canBecomeMain }
            for window in setAside { window.orderOut(nil) }
        } else if setAside.isEmpty {
            // Home was closed before Start, so there's nothing to bring back; it opens afresh instead.
            store?.showHome()
        } else {
            for window in setAside { window.makeKeyAndOrderFront(nil) }
            setAside = []
            NSApp.activate()
        }
    }

    private func showPanel(_ store: BoardStore) {
        let panel = self.panel ?? makePanel(store)
        self.panel = panel
        dock()
        guard !panel.isVisible else { return }
        Self.present(panel)
    }

    /// Up front for real use; behind other apps at normal level for `-quietCapture`.
    static func present(_ window: NSWindow) {
        if LaunchOptions.capturesQuietly {
            window.level = .normal
            window.orderBack(nil)
        } else {
            window.orderFrontRegardless()
        }
    }

    private func dock() {
        guard let panel, let store, let frame = Self.screen(for: store)?.visibleFrame else { return }
        panel.collectionBehavior = store.settings.floatsAboveFullScreen ? [.fullScreenAuxiliary] : []
        let width = Layout.focusPanelWidth
        let x = store.panelSide == .right ? frame.maxX - width : frame.minX
        panel.setFrame(NSRect(x: x, y: frame.minY, width: width, height: frame.height), display: true)
    }

    /// Settings' Panel screen by name, falling back to the menu bar's display when that one is unplugged.
    static func screen(for store: BoardStore) -> NSScreen? {
        NSScreen.screens.first { $0.localizedName == store.settings.panelScreen } ?? NSScreen.main
            ?? NSScreen.screens.first
    }

    private func makePanel(_ store: BoardStore) -> NSPanel {
        let panel = KeyablePanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Focus Panel"
        panel.isFloatingPanel = true
        // Docked beside whatever the person works in, so it stays up when another app is in front.
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: FocusPanelView(store: store))
        return panel
    }
}

/// Borderless panels refuse key status by default, which would leave ADD TASK's field and the notes deaf to typing.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
