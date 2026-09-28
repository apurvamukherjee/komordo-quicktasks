import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The delegate owns the panels (ARCHITECTURE §4.1); `KomodoApp` hands it the store once Home appears.
    let focusSurfaces = FocusSurfaceController()

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Only dark values are designed; Light is P2 (DESIGN_SYSTEM §2).
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
}
