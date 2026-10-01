import Foundation
import Testing

@testable import KomodoCore

struct AppSettingsTests {
    @Test func defaultsMatchTheSettingsTable() {
        let settings = AppSettings(stored: [:])
        #expect(settings == AppSettings())
        #expect(settings.showsInDock && settings.showsMenuBarTimer && !settings.hidesCardTimes)
        #expect(settings.weekStart == .monday)
        #expect(settings.quickPresets == [900, 1_800, 3_600])
        #expect(settings.panelScreen == nil)
        #expect(!settings.timedAlerts && settings.timedAlertInterval == 900 && settings.timedAlertSound == .tick)
        #expect(settings.reminderSound == .chime && settings.volume == 0.7)
        #expect(settings.backsUpDaily && settings.backupFolder == nil && settings.backupsKept == 14)
        #expect(settings.shortcut(for: .showKomodo).label == "⌘⇧B")
    }

    @Test func everySettingRoundTrips() {
        var settings = AppSettings()
        settings.showsInDock = false
        settings.hidesCardTimes = true
        settings.weekStart = .sunday
        settings.quickPresets = [600, 2_700]
        settings.panelScreen = "LG UltraFine"
        settings.floatsAboveFullScreen = false
        settings.defaultBreakLength = 600
        settings.scrollsTitle = false
        settings.opensLinksOnStart = false
        settings.timedAlerts = true
        settings.timedAlertInterval = 1_800
        settings.timedAlertSound = .pop
        settings.pulsesTimer = false
        settings.reminderSound = .glass
        settings.volume = 0.35
        settings.showsSuccessScreen = false
        settings.showsGIF = false
        settings.playsSuccessSound = false
        settings.showsStreaks = false
        settings.backsUpDaily = false
        settings.backupFolder = "/Volumes/Backup Drive/Komodo"
        settings.backupsKept = 30
        settings.lastExportAt = Date(timeIntervalSince1970: 1_790_000_000.25)
        settings.lastBackupAt = Date(timeIntervalSince1970: 1_790_086_400)
        settings.lastBackupFailure = "folder not found"
        settings.protectsBackups = true
        settings.allowsMCP = true
        settings.shortcuts[.findTimer] = KeyCombo(keyCode: 3, modifiers: [.control, .option], key: "f")
        #expect(AppSettings(stored: settings.stored) == settings)
    }

    @Test func aResetShortcutReadsBackAsTheDefault() {
        var settings = AppSettings()
        settings.shortcuts[.togglePanel] = KeyCombo(keyCode: 3, modifiers: [.command], key: "F")
        var reset = settings
        reset.shortcuts[.togglePanel] = nil
        #expect(reset.changes(since: settings) == ["shortcut.togglePanel": ""])
        #expect(AppSettings(stored: reset.stored).shortcut(for: .togglePanel).label == "⌘⇧T")
    }

    @Test func onlyChangedKeysAreWritten() {
        let old = AppSettings()
        var new = old
        new.volume = 0.5
        #expect(new.changes(since: old) == ["volume": "0.5"])
        #expect(old.changes(since: old).isEmpty)
    }

    @Test func unreadableValuesKeepTheirDefaults() {
        let settings = AppSettings(stored: ["weekStart": "someday", "volume": "loud", "shortcut.showKomodo": "x"])
        #expect(settings.weekStart == .monday)
        #expect(settings.volume == 0.7)
        #expect(settings.shortcut(for: .showKomodo) == GlobalShortcut.showKomodo.defaultCombo)
    }

    @Test func keyCombosListCommandFirstAndNeedARealModifier() {
        let combo = KeyCombo(keyCode: 17, modifiers: [.shift, .control, .option, .command], key: "t")
        #expect(combo.caps == ["⌘", "⌃", "⌥", "⇧", "T"])
        #expect(combo.isUsable)
        #expect(!KeyCombo(keyCode: 17, modifiers: [.shift], key: "T").isUsable)
    }

    @Test func weekStartsMapToCalendarWeekdays() {
        #expect(WeekStart.allCases.map(\.firstWeekday) == [2, 1, 7])
    }
}
