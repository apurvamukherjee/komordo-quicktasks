import Foundation

/// Everything in the Settings window that isn't already one of Quick Settings' Focus values (FEATURES §4.18),
/// with the table's defaults. It round-trips through the `preferences` table as strings, one key per setting,
/// so a setting added later reads its default from an older file.
public struct AppSettings: Equatable, Sendable {
    // General
    public var showsInDock = true
    public var showsMenuBarTimer = true
    public var hidesCardTimes = false
    public var weekStart = WeekStart.monday
    public var quickPresets: [TimeInterval] = [15 * 60, 30 * 60, 60 * 60]

    // Focus
    /// A display's name, or nil for whichever display has the menu bar.
    public var panelScreen: String?
    public var floatsAboveFullScreen = true
    /// The length of Start break ⌘⌥B while Pomodoros are off.
    public var defaultBreakLength: TimeInterval = 5 * 60
    public var scrollsTitle = true
    public var opensLinksOnStart = true

    // Alerts & sounds
    public var timedAlerts = false
    public var timedAlertInterval: TimeInterval = 15 * 60
    public var timedAlertSound = KomodoSound.tick
    public var pulsesTimer = true
    public var reminderSound = KomodoSound.chime
    /// 0 to 1, for every Komodo sound.
    public var volume = 0.7

    // Celebration
    public var showsSuccessScreen = true
    public var showsGIF = true
    public var playsSuccessSound = true
    /// The day streak and "in a row today" (FEATURES §4.13).
    public var showsStreaks = true

    // Data & backup
    public var backsUpDaily = true
    /// A folder the user chose, or nil for `~/Documents/Komodo Backups`.
    public var backupFolder: String?
    public var backupsKept = 14
    public var lastExportAt: Date?
    public var lastBackupAt: Date?
    /// Why the last automatic backup failed, shown in danger text until one succeeds.
    public var lastBackupFailure: String?
    /// Backups are sealed as `.kbak`; the password itself is in the Keychain, never here.
    public var protectsBackups = false

    // Calendar import (FEATURES §5, through macOS Calendar)
    public var importsCalendars = false
    /// macOS Calendar's identifiers for the calendars to import; they're particular to this Mac.
    public var calendarIDs: [String] = []
    /// The list imported events join; nil means the first list.
    public var calendarListID: String?
    public var calendarWeeks = 2
    public var calendarAcceptedOnly = false
    public var lastCalendarSync: Date?

    // Local MCP server
    /// Let AI apps on this Mac use Komodo (DESIGN_SYSTEM §13.24); `komodo-mcp` refuses every tool while it's off.
    public var allowsMCP = false

    // Shortcuts
    /// Only the global shortcuts can be changed; a missing entry means the default.
    public var shortcuts: [GlobalShortcut: KeyCombo] = [:]

    public static let presetLimit = 5
    public static let backupsKeptChoices = [7, 14, 30]
    /// FEATURES §5: a range of up to 3 weeks.
    public static let calendarWeekChoices = [1, 2, 3]
    public static let timedAlertIntervals: [TimeInterval] = [5, 10, 15, 30].map { $0 * 60 }

    public init() {}

    public func shortcut(for action: GlobalShortcut) -> KeyCombo { shortcuts[action] ?? action.defaultCombo }

    // MARK: Storage

    private enum Key {
        static let dock = "showsInDock"
        static let menuBarTimer = "showsMenuBarTimer"
        static let hidesCardTimes = "hidesCardTimes"
        static let weekStart = "weekStart"
        static let presets = "quickPresets"
        static let panelScreen = "panelScreen"
        static let floats = "floatsAboveFullScreen"
        static let defaultBreak = "defaultBreakSeconds"
        static let scrollsTitle = "scrollsTitle"
        static let opensLinks = "opensLinksOnStart"
        static let timedAlerts = "timedAlerts"
        static let timedInterval = "timedAlertSeconds"
        static let timedSound = "timedAlertSound"
        static let pulses = "pulsesTimer"
        static let reminderSound = "reminderSound"
        static let volume = "volume"
        static let successScreen = "showsSuccessScreen"
        static let gif = "showsGIF"
        static let successSound = "playsSuccessSound"
        static let streaks = "showsStreaks"
        static let backsUpDaily = "backsUpDaily"
        static let backupFolder = "backupFolder"
        static let backupsKept = "backupsKept"
        static let lastExport = "lastExportAt"
        static let lastBackup = "lastBackupAt"
        static let backupFailure = "lastBackupFailure"
        static let protectsBackups = "protectsBackups"
        static let mcp = "mcpEnabled"
        static let importsCalendars = "importsCalendars"
        static let calendarIDs = "calendarIDs"
        static let calendarList = "calendarListID"
        static let calendarWeeks = "calendarWeeks"
        static let calendarAccepted = "calendarAcceptedOnly"
        static let calendarSync = "lastCalendarSync"
        static let shortcutPrefix = "shortcut."
    }

    /// Reads what's there and keeps the default for anything missing or unreadable.
    public init(stored: [String: String]) {
        func bool(_ key: String, _ value: inout Bool) {
            if let text = stored[key] { value = text == "1" }
        }
        func number(_ key: String, _ value: inout Double) {
            if let parsed = stored[key].flatMap(Double.init) { value = parsed }
        }
        bool(Key.dock, &showsInDock)
        bool(Key.menuBarTimer, &showsMenuBarTimer)
        bool(Key.hidesCardTimes, &hidesCardTimes)
        if let value = stored[Key.weekStart].flatMap(WeekStart.init) { weekStart = value }
        if let text = stored[Key.presets] {
            quickPresets = text.split(separator: ",").compactMap { Double($0) }
        }
        if let text = stored[Key.panelScreen], !text.isEmpty { panelScreen = text }
        bool(Key.floats, &floatsAboveFullScreen)
        number(Key.defaultBreak, &defaultBreakLength)
        bool(Key.scrollsTitle, &scrollsTitle)
        bool(Key.opensLinks, &opensLinksOnStart)
        bool(Key.timedAlerts, &timedAlerts)
        number(Key.timedInterval, &timedAlertInterval)
        if let value = stored[Key.timedSound].flatMap(KomodoSound.init) { timedAlertSound = value }
        bool(Key.pulses, &pulsesTimer)
        if let value = stored[Key.reminderSound].flatMap(KomodoSound.init) { reminderSound = value }
        number(Key.volume, &volume)
        bool(Key.successScreen, &showsSuccessScreen)
        bool(Key.gif, &showsGIF)
        bool(Key.successSound, &playsSuccessSound)
        bool(Key.streaks, &showsStreaks)
        bool(Key.backsUpDaily, &backsUpDaily)
        if let text = stored[Key.backupFolder], !text.isEmpty { backupFolder = text }
        if let value = stored[Key.backupsKept].flatMap(Int.init), value > 0 { backupsKept = value }
        lastExportAt = stored[Key.lastExport].flatMap(Double.init).map(Date.init(timeIntervalSince1970:))
        lastBackupAt = stored[Key.lastBackup].flatMap(Double.init).map(Date.init(timeIntervalSince1970:))
        if let text = stored[Key.backupFailure], !text.isEmpty { lastBackupFailure = text }
        bool(Key.protectsBackups, &protectsBackups)
        bool(Key.mcp, &allowsMCP)
        bool(Key.importsCalendars, &importsCalendars)
        if let text = stored[Key.calendarIDs] {
            calendarIDs = text.split(separator: "\n").map(String.init)
        }
        if let text = stored[Key.calendarList], !text.isEmpty { calendarListID = text }
        if let value = stored[Key.calendarWeeks].flatMap(Int.init), Self.calendarWeekChoices.contains(value) {
            calendarWeeks = value
        }
        bool(Key.calendarAccepted, &calendarAcceptedOnly)
        lastCalendarSync = stored[Key.calendarSync].flatMap(Double.init).map(Date.init(timeIntervalSince1970:))
        for action in GlobalShortcut.allCases {
            if let combo = stored[Key.shortcutPrefix + action.rawValue].flatMap(KeyCombo.init(stored:)) {
                shortcuts[action] = combo
            }
        }
    }

    /// Every setting as its stored string. A reset shortcut stores an empty string, which reads back as the
    /// default.
    public var stored: [String: String] {
        func flag(_ value: Bool) -> String { value ? "1" : "0" }
        var result = [
            Key.dock: flag(showsInDock),
            Key.menuBarTimer: flag(showsMenuBarTimer),
            Key.hidesCardTimes: flag(hidesCardTimes),
            Key.weekStart: weekStart.rawValue,
            Key.presets: quickPresets.map { String(Int($0)) }.joined(separator: ","),
            Key.panelScreen: panelScreen ?? "",
            Key.floats: flag(floatsAboveFullScreen),
            Key.defaultBreak: String(Int(defaultBreakLength)),
            Key.scrollsTitle: flag(scrollsTitle),
            Key.opensLinks: flag(opensLinksOnStart),
            Key.timedAlerts: flag(timedAlerts),
            Key.timedInterval: String(Int(timedAlertInterval)),
            Key.timedSound: timedAlertSound.rawValue,
            Key.pulses: flag(pulsesTimer),
            Key.reminderSound: reminderSound.rawValue,
            Key.volume: String(volume),
            Key.successScreen: flag(showsSuccessScreen),
            Key.gif: flag(showsGIF),
            Key.successSound: flag(playsSuccessSound),
            Key.streaks: flag(showsStreaks),
            Key.backsUpDaily: flag(backsUpDaily),
            Key.backupFolder: backupFolder ?? "",
            Key.backupsKept: String(backupsKept),
            Key.lastExport: lastExportAt.map { String($0.timeIntervalSince1970) } ?? "",
            Key.lastBackup: lastBackupAt.map { String($0.timeIntervalSince1970) } ?? "",
            Key.backupFailure: lastBackupFailure ?? "",
            Key.protectsBackups: flag(protectsBackups),
            Key.mcp: flag(allowsMCP),
            Key.importsCalendars: flag(importsCalendars),
            Key.calendarIDs: calendarIDs.joined(separator: "\n"),
            Key.calendarList: calendarListID ?? "",
            Key.calendarWeeks: String(calendarWeeks),
            Key.calendarAccepted: flag(calendarAcceptedOnly),
            Key.calendarSync: lastCalendarSync.map { String($0.timeIntervalSince1970) } ?? "",
        ]
        for action in GlobalShortcut.allCases {
            result[Key.shortcutPrefix + action.rawValue] = shortcuts[action]?.storedValue ?? ""
        }
        return result
    }

    /// Only what differs from `old`, so a change writes one row rather than all of them.
    public func changes(since old: AppSettings) -> [String: String] {
        let before = old.stored
        return stored.filter { before[$0.key] != $0.value }
    }
}

/// The first day of the Board's week (FEATURES §4.18).
public enum WeekStart: String, CaseIterable, Sendable {
    case monday
    case sunday
    case saturday

    /// `Calendar` numbering, as `WeekRange` takes it.
    public var firstWeekday: Int {
        switch self {
        case .monday: 2
        case .sunday: 1
        case .saturday: 7
        }
    }

    public var title: String { rawValue.capitalized }
}

/// The sounds Settings offers by name (Settings.dc.html).
public enum KomodoSound: String, CaseIterable, Sendable {
    case tick
    case chime
    case pop
    case glass

    public var title: String { rawValue.capitalized }
}
