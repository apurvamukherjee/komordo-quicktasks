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
        BackupSheet(symbol: "square.and.arrow.down", tint: Palette.teal, glyph: Palette.tealText) {
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
        }
    }

    private var symbol: String {
        switch error {
        case .newerVersion: "exclamationmark.circle"
        case .notABackup: "doc.badge.ellipsis"
        case .damaged: "exclamationmark.triangle"
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
        BackupSheet(symbol: "trash", tint: Palette.danger, glyph: Palette.dangerText) {
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

/// `.ds-sheet`: a 42 pt tinted icon beside an 18 pt title, the body, and the buttons trailing.
private struct BackupSheet<Title: View, Content: View, Actions: View>: View {
    var symbol: String
    var tint: Color
    var glyph: Color
    @ViewBuilder var title: Title
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: Space.s3) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(glyph)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                title
                    .font(.system(size: 18, weight: .heavy))
                    .tracking(-0.36)
                    .foregroundStyle(Palette.textPrimary)
            }
            content
                .font(.system(size: 13))
                .foregroundStyle(Palette.textBody)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Space.s2) {
                Spacer()
                actions
            }
        }
        .padding(22)
        .frame(width: Layout.sheetFormWidth)
        .background(Palette.raised)
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
