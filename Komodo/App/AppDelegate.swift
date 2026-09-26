import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // Only dark values are designed; Light is P2 (DESIGN_SYSTEM §2).
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }
}
