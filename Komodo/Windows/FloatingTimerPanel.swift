import AppKit
import SwiftUI

/// The floating timer's window (ARCHITECTURE §4.1): borderless, non-activating, above every app and on every
/// Space. It's a fixed transparent frame with the pill at its leading edge, so the hover controls grow to the
/// right without resizing the window; clicks pass through the transparent part. Its spot is remembered per
/// display and kept on screen (FEATURES §4.9). A second transparent window carries the 320 × 240 celebration
/// above the pill, or below it when the pill sits too close to the top (DESIGN_SYSTEM §13.9).
@MainActor final class FloatingTimerPanel {
    /// Room for the widest pill (a 200 pt title plus six controls) and its glow.
    private static let size = CGSize(width: 600, height: 88)
    /// Where the pill's frame sits inside the window, matching `FloatingTimerView`'s padding.
    private static let inset = CGPoint(x: 24, y: 24)
    /// The celebration card, its caret and room for its glow.
    private static let celebrationSize = CGSize(width: 400, height: 300)

    let window: NSPanel
    private let celebration: NSPanel
    private let celebrationHost: NSHostingView<FloatingCelebration>
    private let store: BoardStore
    private var pillWidth = Layout.floatingTimerMinWidth
    private var dragStart: (mouse: NSPoint, origin: NSPoint)?

    init(store: BoardStore) {
        self.store = store
        window = Self.makeWindow(title: "Floating Timer", size: Self.size)
        celebration = Self.makeWindow(title: "Floating Celebration", size: Self.celebrationSize)
        celebrationHost = NSHostingView(rootView: FloatingCelebration(store: store, isAbovePill: true))
        celebration.contentView = celebrationHost
        let root = FloatingTimerView(
            store: store, onDrag: { [weak self] phase in self?.drag(phase) },
            onPillWidth: { [weak self] width in
                self?.pillWidth = width
                self?.positionCelebration()
            }
        )
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        window.contentView = NSHostingView(rootView: root)
    }

    func show() {
        place()
        FocusSurfaceController.present(window)
        FocusSurfaceController.present(celebration)
    }

    func hide() {
        window.orderOut(nil)
        celebration.orderOut(nil)
    }

    private static func makeWindow(title: String, size: CGSize) -> NSPanel {
        let window = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        window.title = title
        window.isFloatingPanel = true
        window.level = .floating
        window.hidesOnDeactivate = false
        window.becomesKeyOnlyIfNeeded = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = .clear
        // The views draw their own glow; a window shadow would outline the transparent frame.
        window.hasShadow = false
        return window
    }

    /// Centred on the pill, above it when there's room and below it otherwise, caret pointing at it.
    private func positionCelebration() {
        guard let frame = (window.screen ?? NSScreen.main)?.visibleFrame else { return }
        let size = Self.celebrationSize
        let pill = NSRect(
            x: window.frame.minX + Self.inset.x, y: window.frame.minY + Self.inset.y, width: pillWidth,
            height: Layout.floatingTimerHeight)
        let above = pill.maxY + size.height - Self.inset.y <= frame.maxY
        let y = above ? pill.maxY - Self.inset.y + 4 : pill.minY - size.height + Self.inset.y - 4
        celebration.setFrameOrigin(NSPoint(x: pill.midX - size.width / 2, y: y))
        celebrationHost.rootView = FloatingCelebration(store: store, isAbovePill: above)
    }

    /// Puts the window where it was last on the main display, or top center the first time.
    func place() {
        guard let screen = FocusSurfaceController.screen(for: store) else { return }
        let frame = screen.visibleFrame
        let behavior: NSWindow.CollectionBehavior =
            store.settings.floatsAboveFullScreen ? [.canJoinAllSpaces, .fullScreenAuxiliary] : [.canJoinAllSpaces]
        window.collectionBehavior = behavior
        celebration.collectionBehavior = behavior
        let origin =
            Self.saved(for: screen)
            ?? NSPoint(x: frame.midX - Self.inset.x - 150, y: frame.maxY - Self.size.height + Self.inset.y - 8)
        window.setFrameOrigin(Self.clamped(origin, to: frame))
        positionCelebration()
    }

    private func drag(_ phase: FloatingTimerView.DragPhase) {
        switch phase {
        case .changed:
            let mouse = NSEvent.mouseLocation
            let start = dragStart ?? (mouse, window.frame.origin)
            dragStart = start
            window.setFrameOrigin(
                NSPoint(x: start.origin.x + mouse.x - start.mouse.x, y: start.origin.y + mouse.y - start.mouse.y))
            positionCelebration()
        case .ended:
            dragStart = nil
            guard let screen = window.screen ?? NSScreen.main else { return }
            window.setFrameOrigin(Self.clamped(window.frame.origin, to: screen.visibleFrame))
            Self.save(window.frame.origin, for: screen)
            positionCelebration()
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

/// The celebration card with a caret pointing at the pill, or nothing between celebrations.
private struct FloatingCelebration: View {
    var store: BoardStore
    var isAbovePill: Bool

    var body: some View {
        VStack(spacing: -7) {
            if let celebration = store.focus.celebration {
                if !isAbovePill { caret }
                CelebrationCard(
                    message: celebration.message, nextTitle: celebration.nextTitle, size: .floating,
                    onFinish: store.finishCelebration
                )
                .id(celebration.taskID)
                if isAbovePill { caret }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isAbovePill ? .bottom : .top)
        .padding(.vertical, Space.s6)
        .preferredColorScheme(.dark)
    }

    private var caret: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Palette.lime)
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(45))
            .zIndex(-1)
    }
}
