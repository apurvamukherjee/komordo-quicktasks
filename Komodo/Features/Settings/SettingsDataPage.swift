import AppKit
import KomodoCore
import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// Data & backup (DESIGN_SYSTEM §13.21, DataSheets.png): export, the daily backup, restore and the danger zone.
struct SettingsDataPage: View {
    @Bindable var store: BoardStore

    @State private var archive: BackupArchive?
    @State private var failure: BackupError?
    @State private var isRestoring = false
    @State private var isConfirmingDelete = false
    @State private var isSettingPassword = false
    /// A `.kbak` waiting for its password.
    @State private var lockedFile: URL?
    @State private var isWrongPassword = false
    @State private var isUnlocking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroup(title: "BACKUP") {
                SettingsRow("Export backup", detail: exportDetail) {
                    Button(store.isExporting ? "Exporting…" : "Export zip", systemImage: "square.and.arrow.up") {
                        store.chooseExportDestination()
                    }
                    .buttonStyle(.komodo(.primary, size: .small, isBusy: store.isExporting))
                    .disabled(store.database == nil)
                }
                SettingsRow(
                    "Automatic daily backup", detail: "A zip a day, within 5 minutes of the first launch.",
                    isOn: $store.settings.backsUpDaily)
                Group {
                    SettingsRow("Folder", isIndented: true) {
                        folderLabel
                        Button("Change") { chooseFolder() }.buttonStyle(.komodo(.secondary, size: .small))
                        Button("Show") { showFolder() }.buttonStyle(.komodo(.ghost, size: .small))
                    }
                    keepRow
                    Label(
                        "Tip: choose an iCloud Drive or Dropbox folder for a copy off this Mac.", systemImage: "icloud"
                    )
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)
                    .labelStyle(TipLabelStyle())
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                    .padding(.leading, 50)
                    .padding(.bottom, Space.s1)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                    }
                }
                .opacity(store.settings.backsUpDaily ? 1 : 0.4)
                .disabled(!store.settings.backsUpDaily)
                SettingsRow("Password-protect backups", detail: "Saved as an encrypted .kbak file.") {
                    SettingsSwitch(title: "Password-protect backups", isOn: protectsBackups)
                        .disabled(store.database == nil)
                }
            }
            SettingsGroup(title: "RESTORE") {
                SettingsRow(
                    "Restore from backup", detail: "Replaces all current data. Your current data is backed up first."
                ) {
                    Button("Choose file…", systemImage: "square.and.arrow.down") { chooseBackup() }
                        .buttonStyle(.komodo(.secondary, size: .small))
                        .disabled(store.database == nil)
                }
            }
            SettingsGroup(title: "DANGER ZONE", isDanger: true) {
                // The spec's "and disconnects Google" waits for Gmail → Calendar.
                SettingsRow("Delete all data", detail: "Deletes every list, task, and session on this Mac.") {
                    Button("Delete all data") { isConfirmingDelete = true }
                        .buttonStyle(.komodo(.danger, size: .small))
                        .disabled(store.database == nil)
                }
            }
        }
        .animation(Motion.base, value: store.settings.backsUpDaily)
        .task {
            #if DEBUG
                // `-openRestore <file>`, `-openDeleteAll YES` and `-openBackupPassword YES` show the sheets for
                // captures without the pointer.
                if let path = UserDefaults.standard.string(forKey: "openRestore") { await open(URL(filePath: path)) }
                isConfirmingDelete = UserDefaults.standard.bool(forKey: "openDeleteAll")
                isSettingPassword = UserDefaults.standard.bool(forKey: "openBackupPassword")
            #endif
        }
        .task(id: store.backupToOpen) {
            guard let url = store.backupToOpen, store.database != nil else { return }
            store.backupToOpen = nil
            await open(url)
        }
        .sheet(isPresented: Binding(get: { archive != nil }, set: { if !$0 { cancelRestore() } })) {
            if let archive {
                RestoreBackupSheet(
                    archive: archive, isRestoring: isRestoring, cancel: cancelRestore,
                    restore: { restore(archive) })
            }
        }
        .sheet(isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            if let failure {
                RestoreErrorSheet(
                    error: failure, dismiss: { self.failure = nil },
                    chooseAnother: {
                        self.failure = nil
                        chooseBackup()
                    })
            }
        }
        .sheet(isPresented: $isSettingPassword) {
            SetBackupPasswordSheet(
                cancel: { isSettingPassword = false },
                save: { if store.protectBackups(with: $0) { isSettingPassword = false } })
        }
        .sheet(isPresented: Binding(get: { lockedFile != nil }, set: { if !$0 { lockedFile = nil } })) {
            if let lockedFile {
                OpenBackupPasswordSheet(
                    fileName: lockedFile.lastPathComponent, isWrong: isWrongPassword, isOpening: isUnlocking,
                    cancel: { self.lockedFile = nil }, open: { unlock(lockedFile, with: $0) })
            }
        }
        .sheet(isPresented: $isConfirmingDelete) {
            DeleteAllDataSheet(
                cancel: { isConfirmingDelete = false },
                delete: {
                    isConfirmingDelete = false
                    store.deleteAllData()
                })
        }
    }

    // MARK: Rows

    /// On asks for a password first; the switch only flips once it's in the Keychain.
    private var protectsBackups: Binding<Bool> {
        Binding(
            get: { store.settings.protectsBackups },
            set: { isOn in
                if isOn { isSettingPassword = true } else { store.stopProtectingBackups() }
            })
    }

    private var exportDetail: Text {
        if store.isExporting { return Text("Writing \(store.suggestedBackupName)…") }
        return Text("Everything except passwords and tokens. Last export: ")
            + Text(store.settings.lastExportAt.map(Self.stamp) ?? "never").foregroundColor(Palette.textTertiary)
            .monospacedDigit() + Text(".")
    }

    private var folderLabel: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
        return HStack(spacing: 7) {
            Image(systemName: "folder")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(store.settings.lastBackupFailure == nil ? Palette.greenText : Palette.dangerText)
            Text(store.backupFolderLabel)
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.textBody)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 260, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color.white.opacity(0.04), in: shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        .help(store.backupFolder.path(percentEncoded: false))
    }

    /// "Keep last 14 backups" with the last backup, or why it failed, at the trailing edge.
    private var keepRow: some View {
        HStack(spacing: Space.s3) {
            Text("Keep last")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Palette.textTertiary)
            SettingsMenuPicker(
                title: "Keep last", selection: $store.settings.backupsKept,
                options: AppSettings.backupsKeptChoices.map { ($0, "\($0)") })
            Text("backups").font(.system(size: 12)).foregroundStyle(Palette.textMuted)
            Spacer(minLength: Space.s4)
            lastBackup
        }
        .padding(.leading, 50)
        .padding(.trailing, Space.s4)
        .frame(minHeight: 56)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
        }
    }

    @ViewBuilder private var lastBackup: some View {
        if let failure = store.settings.lastBackupFailure {
            Text("Last backup failed: \(failure)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.dangerText)
        } else if let last = store.settings.lastBackupAt {
            HStack(spacing: 6) {
                Text("Last backup:").foregroundStyle(Palette.textTertiary)
                Text(Self.stamp(last)).fontWeight(.semibold).monospacedDigit().foregroundStyle(Palette.textPrimary)
                Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.green)
            }
            .font(.system(size: 12))
        } else {
            Text("No backup yet").font(.system(size: 12)).foregroundStyle(Palette.textMuted)
        }
    }

    /// "Today 9:05 AM" or "Sep 24, 6:12 PM", as the canvas writes them.
    private static func stamp(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? "Today " + date.formatted(.dateTime.hour().minute())
            // Apart, so locales that join a date and time with "at" still read "Sep 24, 6:12 PM".
            : date.formatted(.dateTime.month(.abbreviated).day()) + ", " + date.formatted(.dateTime.hour().minute())
    }

    // MARK: Actions

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = store.backupFolder
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.settings.backupFolder = url.path(percentEncoded: false)
        store.settings.lastBackupFailure = nil
    }

    private func showFolder() {
        do {
            try FileManager.default.createDirectory(at: store.backupFolder, withIntermediateDirectories: true)
            NSWorkspace.shared.open(store.backupFolder)
        } catch {
            Logger(subsystem: "app.komodo.Komodo", category: "backup").error("Show folder: \(error)")
            store.settings.lastBackupFailure = "folder not found"
        }
    }

    private func chooseBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip, .komodoBackup]
        panel.directoryURL = store.backupFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await open(url) }
    }

    private func open(_ url: URL) async {
        switch await BoardStore.openBackup(url) {
        case .success(let opened): archive = opened
        case .failure(.passwordRequired):
            isWrongPassword = false
            lockedFile = url
        case .failure(let error): failure = error
        }
    }

    private func unlock(_ url: URL, with password: String) {
        isUnlocking = true
        Task {
            let result = await BoardStore.openBackup(url, password: password)
            isUnlocking = false
            switch result {
            case .success(let opened):
                lockedFile = nil
                archive = opened
            case .failure(.wrongPassword):
                isWrongPassword = true
            case .failure(let error):
                lockedFile = nil
                failure = error
            }
        }
    }

    private func restore(_ archive: BackupArchive) {
        isRestoring = true
        Task {
            let restored = await store.restore(archive)
            isRestoring = false
            self.archive = nil
            if restored {
                store.toasts.show(Toast(kind: .success, message: "Restored.", detail: archive.fileName))
            }
        }
    }

    private func cancelRestore() {
        guard !isRestoring, let archive else { return }
        store.discard(archive)
        self.archive = nil
    }
}

private struct TipLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Space.s2) {
            configuration.icon.font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.cyan)
            configuration.title
        }
    }
}

#Preview("Data & backup") {
    SettingsDataPage(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
        .environment(\.settingsTint, SettingsSection.data.spotlight)
        .padding(28)
        .frame(width: 864, height: 720, alignment: .top)
        .background(Palette.bg)
}
