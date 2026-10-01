import AppKit
import KomodoCore
import OSLog
import UniformTypeIdentifiers

/// Data & backup's actions (FEATURES §4.21): zip export, the daily automatic backup, restore and Delete all data.
/// The zip work runs off the main thread; the board only changes once a restore or delete has succeeded.
extension BoardStore {
    static let defaultBackupFolder = URL.documentsDirectory.appending(path: "Komodo Backups")

    var backupFolder: URL { settings.backupFolder.map { URL(filePath: $0) } ?? Self.defaultBackupFolder }

    /// The folder as the page writes it, with the home folder as ~.
    var backupFolderLabel: String {
        let path = backupFolder.path(percentEncoded: false)
        let home = URL.homeDirectory.path(percentEncoded: false)
        return path.hasPrefix(home) ? "~/" + path.dropFirst(home.count).trimmingPrefix("/") : path
    }

    nonisolated private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private static let log = Logger(subsystem: "app.komodo.Komodo", category: "backup")

    // MARK: Password

    /// Password-protect backups: saves the password in the Keychain first, so the switch only turns on once a
    /// backup can really be sealed.
    func protectBackups(with password: String) -> Bool {
        do {
            try BackupPassword.save(password)
        } catch {
            Self.log.error("Couldn't save the backup password: \(error)")
            toasts.show(Toast(kind: .error, message: "Couldn't save the password in your Keychain"))
            return false
        }
        settings.protectsBackups = true
        return true
    }

    func stopProtectingBackups() {
        settings.protectsBackups = false
        do {
            try BackupPassword.remove()
        } catch {
            // Harmless left behind: nothing reads it while protection is off, and turning it on replaces it.
            Self.log.error("Couldn't remove the backup password: \(error)")
        }
    }

    /// The password backups are sealed with, or nil while protection is off.
    private func sealingPassword() throws -> String? {
        guard settings.protectsBackups else { return nil }
        guard let password = try BackupPassword.read() else { throw MissingBackupPassword() }
        return password
    }

    // MARK: Export

    /// Export zip: the spinner, then "Backup saved" with Show in Finder.
    func exportBackup(to destination: URL) async {
        guard let database, !isExporting else { return }
        isExporting = true
        defer { isExporting = false }
        do {
            let password = try sealingPassword()
            try await Self.write(database, to: destination, password: password)
            settings.lastExportAt = now
            toasts.show(
                Toast(
                    kind: .success, message: "Backup saved: \(destination.lastPathComponent)",
                    action: .init(title: "Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([destination])
                    }))
        } catch {
            Self.log.error("Export failed: \(error)")
            toasts.show(Toast(kind: .error, message: "Couldn't save the backup", detail: destination.lastPathComponent))
        }
    }

    /// Export zip and the palette's Export Backup: the standard Save panel with today's name filled in.
    func chooseExportDestination() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedBackupName
        panel.allowedContentTypes = [settings.protectsBackups ? .komodoBackup : .zip]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await exportBackup(to: url) }
    }

    var suggestedBackupName: String {
        Backup.fileName(on: now, calendar: calendar, isProtected: settings.protectsBackups)
    }

    // MARK: Automatic

    /// The daily zip, within minutes of the first launch each day (FEATURES §4.21), then the oldest beyond Keep
    /// last are removed. A failure is shown on the page until the next backup works.
    func backUpIfDue() async {
        guard database != nil, settings.backsUpDaily, !isExporting else { return }
        if let last = settings.lastBackupAt, calendar.isDate(last, inSameDayAs: now) { return }
        await backUp(named: suggestedBackupName)
    }

    @discardableResult
    private func backUp(named name: String) async -> Bool {
        guard let database else { return false }
        let folder = backupFolder
        let kept = settings.backupsKept
        do {
            let password = try sealingPassword()
            try await Task.detached {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try Backup.export(
                    database, appVersion: Self.appVersion, to: folder.appending(path: name), password: password)
                try Backup.prune(folder, keeping: kept)
            }.value
            settings.lastBackupAt = now
            settings.lastBackupFailure = nil
            return true
        } catch {
            Self.log.error("Automatic backup failed: \(error)")
            if error is MissingBackupPassword || error is KeychainError {
                settings.lastBackupFailure = "the password isn't in your Keychain"
                return false
            }
            // The folder is made when missing, so a missing parent means an unplugged drive or a moved folder.
            let isMissing = !FileManager.default.fileExists(atPath: folder.deletingLastPathComponent().path)
            settings.lastBackupFailure = isMissing ? "folder not found" : "couldn't write to the folder"
            return false
        }
    }

    // MARK: Restore and delete

    /// Checks a chosen zip without touching the current data.
    static func openBackup(_ zip: URL) async -> Result<BackupArchive, BackupError> {
        await Task.detached { Result { () throws(BackupError) in try Backup.open(zip) } }.value
    }

    /// Backs the current data up next to the automatic ones, then copies the backup in. Nothing is replaced if
    /// the safety copy can't be written.
    func restore(_ archive: BackupArchive) async -> Bool {
        guard let database else { return false }
        defer { discard(archive) }
        let safety = Backup.fileName(on: now, calendar: calendar, suffix: "before-restore")
        guard await backUp(named: safety) else {
            toasts.show(
                Toast(
                    kind: .error, message: "Couldn't back up your current data",
                    detail: "Nothing was replaced. Check the backup folder."))
            return false
        }
        do {
            try await Task.detached { try database.replaceContents(with: archive) }.value
        } catch {
            Self.log.error("Restore failed: \(error)")
            toasts.show(Toast(kind: .error, message: "The backup is damaged.", detail: "Nothing was replaced."))
            return false
        }
        // Where this Mac backs up, and how that went, describe the Mac rather than the data, so the backup's
        // older values don't replace them.
        let local = settings
        reload()
        settings.backupFolder = local.backupFolder
        settings.lastExportAt = local.lastExportAt
        settings.lastBackupAt = local.lastBackupAt
        settings.lastBackupFailure = local.lastBackupFailure
        return true
    }

    func discard(_ archive: BackupArchive) {
        do {
            try archive.discard()
        } catch {
            Self.log.error("Couldn't remove the unzipped backup: \(error)")
        }
    }

    /// Delete all data: an empty file and a first-launch board. There's no Google connection to drop yet.
    func deleteAllData() {
        guard let database else { return }
        do {
            try database.eraseAll()
        } catch {
            Self.log.error("Delete all data failed: \(error)")
            toasts.show(Toast(kind: .error, message: "Couldn't delete your data", detail: "Nothing was deleted."))
            return
        }
        reload()
    }

    private static func write(_ database: AppDatabase, to destination: URL, password: String?) async throws {
        try await Task.detached {
            try Backup.export(database, appVersion: appVersion, to: destination, password: password)
        }.value
    }
}

/// Protection is on but the Keychain has no password, as after it was deleted in Keychain Access.
private struct MissingBackupPassword: Error {}

extension UTType {
    /// `.kbak`, a password-protected backup.
    static let komodoBackup = UTType(filenameExtension: BackupCrypto.fileExtension) ?? .data
}
