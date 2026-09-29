import AppKit
import SwiftUI

/// Owns the Settings window. It's an AppKit window rather than a SwiftUI scene so every way in (⌘,, the sidebar,
/// Quick Settings inside the Focus Panel's own panel, the palette, the menu bar) reaches it through the store,
/// and so it can hide its title bar like Home.
@MainActor final class SettingsWindowController {
    private var store: BoardStore?
    private var window: NSWindow?

    func attach(_ store: BoardStore) {
        guard self.store == nil else { return }
        self.store = store
        observe()
        #if DEBUG
            if let page = UserDefaults.standard.string(forKey: "openSettings") {
                store.showSettings(SettingsSection(rawValue: page) ?? .general)
            }
        #endif
    }

    private func observe() {
        guard let store else { return }
        withObservationTracking {
            _ = store.settingsRequests
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.show()
                self?.observe()
            }
        }
    }

    private func show() {
        guard let store else { return }
        let window = self.window ?? makeWindow(store)
        self.window = window
        if LaunchOptions.capturesQuietly {
            window.orderBack(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
        }
    }

    private func makeWindow(_ store: BoardStore) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Layout.settingsWindow),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = "Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentMinSize = Layout.settingsMin
        window.contentView = NSHostingView(rootView: SettingsView(store: store))
        window.setContentSize(Layout.settingsWindow)
        window.center()
        window.setFrameAutosaveName("Settings")
        return window
    }
}
