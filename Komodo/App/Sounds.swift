import AppKit
import KomodoCore

/// macOS's own sounds stand in for Komodo's until it bundles its own (`success.caf` and friends).
extension KomodoSound {
    private var systemName: NSSound.Name {
        switch self {
        case .tick: "Tink"
        case .chime: "Ping"
        case .pop: "Pop"
        case .glass: "Glass"
        }
    }

    @MainActor func play(volume: Double) {
        Self.play(systemName, volume: volume)
    }

    /// The short fanfare on Done (Celebration's Success sound).
    @MainActor static func playSuccess(volume: Double) {
        play("Hero", volume: volume)
    }

    // A copy, because `NSSound(named:)` hands back one shared instance and a second play would cut the first.
    @MainActor private static func play(_ name: NSSound.Name, volume: Double) {
        guard let sound = NSSound(named: name)?.copy() as? NSSound else { return }
        sound.volume = Float(volume)
        sound.play()
    }
}
