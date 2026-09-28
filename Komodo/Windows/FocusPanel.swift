import AppKit
import SwiftUI

/// Docks the Focus Panel (ARCHITECTURE §4.1): a non-activating panel 340 pt wide and as tall as the screen's
/// visible frame, on the edge Quick Settings picks. While it's up the Home window steps aside, and it comes
/// back when the panel closes (FEATURES §4.8).
@MainActor final class FocusPanelController {
    private var store: BoardStore?
    private var panel: NSPanel?
    private var setAside: [NSWindow] = []

    func attach(_ store: BoardStore) {
        guard self.store == nil else { return }
        self.store = store
        sync()
        observe()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.dock() }
        }
    }

    /// Observation fires once per registration, so each change re-registers after syncing.
    private func observe() {
        guard let store else { return }
        withObservationTracking {
            _ = store.isFocusPanelOpen
            _ = store.panelSide
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.sync()
                self?.observe()
            }
        }
    }

    private func sync() {
        guard let store else { return }
        if store.isFocusPanelOpen { show(store) } else { hide() }
    }

    private func show(_ store: BoardStore) {
        let panel = self.panel ?? makePanel(store)
        self.panel = panel
        dock()
        guard !panel.isVisible else { return }
        setAside = NSApp.windows.filter { $0 !== panel && $0.isVisible && $0.canBecomeMain }
        for window in setAside { window.orderOut(nil) }
        if LaunchOptions.capturesQuietly {
            panel.level = .normal
            panel.orderBack(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    private func hide() {
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        for window in setAside { window.makeKeyAndOrderFront(nil) }
        setAside = []
        NSApp.activate()
    }

    private func dock() {
        guard let panel, let store, let frame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame else {
            return
        }
        let width = Layout.focusPanelWidth
        let x = store.panelSide == .right ? frame.maxX - width : frame.minX
        panel.setFrame(NSRect(x: x, y: frame.minY, width: width, height: frame.height), display: true)
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
        panel.collectionBehavior = [.fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: FocusPanelView(store: store))
        return panel
    }
}

/// Borderless panels refuse key status by default, which would leave ADD TASK's field and the notes deaf to typing.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
