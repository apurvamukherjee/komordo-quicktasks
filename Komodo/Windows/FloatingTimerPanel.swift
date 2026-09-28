import AppKit
import SwiftUI

/// The floating timer's window (ARCHITECTURE §4.1): borderless, non-activating, above every app and on every
/// Space. It's a fixed transparent frame with the pill at its leading edge, so the hover controls grow to the
/// right without resizing the window; clicks pass through the transparent part. Its spot is remembered per
/// display and kept on screen (FEATURES §4.9).
@MainActor final class FloatingTimerPanel {
    /// Room for the widest pill (a 200 pt title plus six controls) and its glow.
    private static let size = CGSize(width: 600, height: 88)
    /// Where the pill's frame sits inside the window, matching `FloatingTimerView`'s padding.
    private static let inset = CGPoint(x: 24, y: 24)

    let window: NSPanel
    private var dragStart: (mouse: NSPoint, origin: NSPoint)?

    init(store: BoardStore) {
        window = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: Self.size), styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        window.title = "Floating Timer"
        window.isFloatingPanel = true
        window.level = .floating
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = .clear
        // The pill draws its own glow; a window shadow would outline the transparent frame.
        window.hasShadow = false
        let root = FloatingTimerView(store: store) { [weak self] phase in self?.drag(phase) }
            .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        window.contentView = NSHostingView(rootView: root)
    }

    /// Puts the window where it was last on the main display, or top center the first time.
    func place() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = screen.visibleFrame
        let origin =
            Self.saved(for: screen)
            ?? NSPoint(x: frame.midX - Self.inset.x - 150, y: frame.maxY - Self.size.height + Self.inset.y - 8)
        window.setFrameOrigin(Self.clamped(origin, to: frame))
    }

    private func drag(_ phase: FloatingTimerView.DragPhase) {
        switch phase {
        case .changed:
            let mouse = NSEvent.mouseLocation
            let start = dragStart ?? (mouse, window.frame.origin)
            dragStart = start
            window.setFrameOrigin(
                NSPoint(x: start.origin.x + mouse.x - start.mouse.x, y: start.origin.y + mouse.y - start.mouse.y))
        case .ended:
            dragStart = nil
            guard let screen = window.screen ?? NSScreen.main else { return }
            window.setFrameOrigin(Self.clamped(window.frame.origin, to: screen.visibleFrame))
            Self.save(window.frame.origin, for: screen)
        }
    }

    /// Keeps the pill itself on screen; the transparent margin may hang off the edge.
    private static func clamped(_ origin: NSPoint, to frame: NSRect) -> NSPoint {
        let minX = frame.minX - inset.x
        let maxX = frame.maxX - inset.x - Layout.floatingTimerMinWidth
        let minY = frame.minY - inset.y
        let maxY = frame.maxY - size.height + inset.y
        return NSPoint(x: min(max(origin.x, minX), maxX), y: min(max(origin.y, minY), maxY))
    }

    private static func key(for screen: NSScreen) -> String? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)
            .map { "floatingTimerOrigin.\($0)" }
    }

    private static func saved(for screen: NSScreen) -> NSPoint? {
        guard let key = key(for: screen), let text = UserDefaults.standard.string(forKey: key) else { return nil }
        return NSPointFromString(text)
    }

    private static func save(_ origin: NSPoint, for screen: NSScreen) {
        guard let key = key(for: screen) else { return }
        UserDefaults.standard.set(NSStringFromPoint(origin), forKey: key)
    }
}
