import Foundation

/// A key with modifiers, as a global shortcut stores it: the hardware key code the system registers, plus the
/// key's printed label for display, since a key code alone doesn't say what the keyboard layout prints.
public struct KeyCombo: Hashable, Sendable {
    public struct Modifiers: OptionSet, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let control = Modifiers(rawValue: 1 << 3)
    }

    public var keyCode: UInt32
    public var modifiers: Modifiers
    public var key: String

    public init(keyCode: UInt32, modifiers: Modifiers, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key.uppercased()
    }

    /// One symbol per cap, ⌘ first as the spec writes them: ["⌘", "⇧", "B"].
    public var caps: [String] {
        let order: [(Modifiers, String)] = [(.command, "⌘"), (.control, "⌃"), (.option, "⌥"), (.shift, "⇧")]
        return order.filter { modifiers.contains($0.0) }.map(\.1) + [key]
    }

    public var label: String { caps.joined() }

    /// Without ⌘, ⌥ or ⌃ a shortcut would swallow ordinary typing in every app.
    public var isUsable: Bool { !modifiers.intersection([.command, .option, .control]).isEmpty && !key.isEmpty }

    var storedValue: String { "\(modifiers.rawValue):\(keyCode):\(key)" }

    init?(stored: String) {
        let parts = stored.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3, let modifiers = Int(parts[0]), let keyCode = UInt32(parts[1]), !parts[2].isEmpty
        else { return nil }
        self.init(keyCode: keyCode, modifiers: Modifiers(rawValue: modifiers), key: String(parts[2]))
    }
}

/// The shortcuts that work from any app (FEATURES §4.17); the rest are the app's menu shortcuts.
public enum GlobalShortcut: String, CaseIterable, Sendable {
    case showKomodo
    case togglePanel
    case findTimer

    public var title: String {
        switch self {
        case .showKomodo: "Show Komodo"
        case .togglePanel: "Toggle Focus Panel / floating timer"
        case .findTimer: "Find the floating timer"
        }
    }

    /// B, T and P on an ANSI keyboard, with ⌘⇧.
    public var defaultCombo: KeyCombo {
        switch self {
        case .showKomodo: KeyCombo(keyCode: 11, modifiers: [.command, .shift], key: "B")
        case .togglePanel: KeyCombo(keyCode: 17, modifiers: [.command, .shift], key: "T")
        case .findTimer: KeyCombo(keyCode: 35, modifiers: [.command, .shift], key: "P")
        }
    }
}
