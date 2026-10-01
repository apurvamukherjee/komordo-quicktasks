import KomodoCore
import SwiftUI

/// DESIGN_SYSTEM §13.22's confirm: the backup's name, date, version and counts before anything is replaced.
struct RestoreBackupSheet: View {
    var archive: BackupArchive
    var isRestoring: Bool
    var cancel: () -> Void
    var restore: () -> Void

    var body: some View {
        let manifest = archive.manifest
        FormSheet(symbol: "square.and.arrow.down", tint: Palette.teal, glyph: Palette.tealText) {
            Text("Restore this backup?")
        } content: {
            VStack(alignment: .leading, spacing: Space.s1) {
                Text(archive.fileName)
                    .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.textPrimary)
                Text(
                    manifest.exportedAt.formatted(.dateTime.month(.abbreviated).day().year())
                        + " · Komodo \(manifest.appVersion)"
                )
                .font(.system(size: 12))
                .foregroundStyle(Palette.textSecondary)
                HStack(spacing: 6) {
                    Chip(Self.count(manifest.counts.lists, "list"))
                    Chip(Self.count(manifest.counts.tasks, "task"))
                    Chip(Self.count(manifest.counts.sessions, "session"))
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, Space.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .spotlight(Palette.teal, radius: Radius.tile, lifts: false) { TileSurface() }
            Text("Your current data is backed up first, then replaced.")
        } actions: {
            Button("Cancel", action: cancel)
                .buttonStyle(.komodo(.secondary))
                .keyboardShortcut(.cancelAction)
                .disabled(isRestoring)
            Button("Restore", action: restore)
                .buttonStyle(.komodo(.primary, isBusy: isRestoring))
                .keyboardShortcut(.defaultAction)
                .disabled(isRestoring)
        }
    }

    private static func count(_ value: Int, _ noun: String) -> String {
        "\(value.formatted()) \(noun)\(value == 1 ? "" : "s")"
    }
}

/// The three refusals (DataSheets.png). Nothing has been replaced when one shows.
struct RestoreErrorSheet: View {
    var error: BackupError
    var dismiss: () -> Void
    var chooseAnother: () -> Void

    var body: some View {
        HStack(spacing: Space.s3) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.dangerText)
                .frame(width: 34, height: 34)
                .background(Palette.danger.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.control))
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if error == .notABackup {
                Button("Cancel", action: dismiss)
                    .buttonStyle(.komodo(.ghost, size: .small))
                    .keyboardShortcut(.cancelAction)
                Button("Choose another…", action: chooseAnother)
                    .buttonStyle(.komodo(.secondary, size: .small))
                    .keyboardShortcut(.defaultAction)
            } else {
                // Check for Updates waits for the signed release, so a newer backup only gets OK for now.
                Button("OK", action: dismiss)
                    .buttonStyle(.komodo(.secondary, size: .small))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, Space.s4)
        .padding(.vertical, 14)
        .frame(width: Layout.sheetFormWidth)
        .background(Palette.raised)
    }

    private var message: String {
        switch error {
        case .newerVersion: "This backup is from a newer version of Komodo. Update the app first."
        case .notABackup: "This file isn't a Komodo backup."
        case .damaged: "The backup is damaged."
        case .passwordRequired, .wrongPassword: "That password doesn't open this backup."
        }
    }

    private var symbol: String {
        switch error {
        case .newerVersion: "exclamationmark.circle"
        case .notABackup: "doc.badge.ellipsis"
        case .damaged: "exclamationmark.triangle"
        case .passwordRequired, .wrongPassword: "lock"
        }
    }
}

/// Delete all data's typed confirm: Delete all stays off until the field reads exactly DELETE.
struct DeleteAllDataSheet: View {
    var cancel: () -> Void
    var delete: () -> Void

    @State private var typed = ""

    private var isArmed: Bool { typed == "DELETE" }

    var body: some View {
        FormSheet(symbol: "trash", tint: Palette.danger, glyph: Palette.dangerText) {
            Text("Delete all data?")
        } content: {
            Text("This deletes every list, task, and session on this Mac.")
            VStack(alignment: .leading, spacing: 6) {
                (Text("Type ")
                    + Text("DELETE").font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Palette.textPrimary) + Text(" to confirm"))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)
                KomodoTextField("DELETE", text: $typed, variant: .monospaced, focusesOnAppear: true)
                    .accessibilityLabel("Type DELETE to confirm")
            }
        } actions: {
            Button("Cancel", action: cancel)
                .buttonStyle(.komodo(.secondary))
                .keyboardShortcut(.cancelAction)
            Button("Delete all", action: delete)
                .buttonStyle(.komodo(.danger))
                .keyboardShortcut(.defaultAction)
                .disabled(!isArmed)
        }
    }
}

/// Password-protect backups: the password twice before the switch turns on. It can't be recovered, so the sheet
/// says so before anything is sealed with it.
struct SetBackupPasswordSheet: View {
    var cancel: () -> Void
    var save: (String) -> Void

    @State private var password = ""
    @State private var confirmation = ""

    private var mismatch: String? {
        !confirmation.isEmpty && confirmation != password ? "The passwords don't match." : nil
    }

    var body: some View {
        FormSheet(symbol: "lock", tint: Palette.teal, glyph: Palette.tealText) {
            Text("Set a backup password")
        } content: {
            Text(
                "Backups are saved as encrypted .kbak files. Komodo keeps the password in your Keychain for the daily backup."
            )
            VStack(alignment: .leading, spacing: Space.s2) {
                KomodoTextField("Password", text: $password, variant: .secure, focusesOnAppear: true)
                    .accessibilityLabel("Password")
                KomodoTextField("Confirm password", text: $confirmation, variant: .secure, error: mismatch)
                    .accessibilityLabel("Confirm password")
            }
            Text("Without this password, a protected backup can't be opened, on this Mac or any other.")
                .foregroundStyle(Palette.textSecondary)
        } actions: {
            Button("Cancel", action: cancel)
                .buttonStyle(.komodo(.secondary))
                .keyboardShortcut(.cancelAction)
            Button("Turn on") { save(password) }
                .buttonStyle(.komodo(.primary))
                .keyboardShortcut(.defaultAction)
                .disabled(password.isEmpty || confirmation != password)
        }
    }
}

#Preview("Delete all data") {
    DeleteAllDataSheet(cancel: {}, delete: {})
}

#Preview("Restore errors") {
    VStack(spacing: Space.s3) {
        RestoreErrorSheet(error: .newerVersion, dismiss: {}, chooseAnother: {})
        RestoreErrorSheet(error: .notABackup, dismiss: {}, chooseAnother: {})
        RestoreErrorSheet(error: .damaged, dismiss: {}, chooseAnother: {})
    }
    .padding(Space.s6)
    .background(Palette.bg)
}

#Preview("Backup password") {
    VStack(spacing: Space.s4) {
        SetBackupPasswordSheet(cancel: {}, save: { _ in })
    }
    .padding(Space.s6)
    .background(Palette.bg)
}
