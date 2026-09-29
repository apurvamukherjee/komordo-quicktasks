import AppKit
import KomodoCore
import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// About (Settings.dc.html): the app icon, version and the local-only promise. Updates arrive with the signed
/// release (ARCHITECTURE §15), so Check for Updates waits for it.
struct SettingsAboutPage: View {
    @Bindable var store: BoardStore

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floats = false

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            appIcon
            (Text("Komodo ")
                + Text(Self.version).font(.system(size: 24, weight: .semibold).monospacedDigit())
                .foregroundColor(Palette.textSecondary))
                .font(.system(size: 24, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, 22)
            Text("To-do list and focus timer for macOS")
                .font(.system(size: 13))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 6)
            Button {
            } label: {
                Label("Check for Updates…", systemImage: "arrow.clockwise")
            }
            .buttonStyle(KomodoButtonStyle(kind: .secondary))
            .disabled(true)
            .help("Updates arrive with the first signed release")
            .padding(.top, 22)
            Button {
                saveDiagnostics()
            } label: {
                Label("Save Diagnostics…", systemImage: "doc.text")
            }
            .buttonStyle(KomodoButtonStyle(kind: .secondary, size: .small))
            .padding(.top, 14)
            Label("Komodo is a local app: no account, no tracking.", systemImage: "checkmark.shield")
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.textBody)
                .labelStyle(PromiseLabelStyle())
                .padding(.horizontal, Space.s4)
                .padding(.vertical, Space.s3)
                .spotlight(Palette.green, radius: Radius.tile, lifts: false) { TileSurface() }
                .padding(.top, 34)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .onAppear { floats = !reduceMotion }
    }

    /// `.st-appicon` with the canvas's `.k-float` bob.
    private var appIcon: some View {
        let shape = RoundedRectangle(cornerRadius: 27, style: .continuous)
        return KomodoMarkShape()
            .stroke(
                LinearGradient(
                    colors: [Palette.teal, Palette.lime], startPoint: .topLeading, endPoint: .bottomTrailing),
                style: StrokeStyle(lineWidth: 7.4, lineCap: .round, lineJoin: .round)
            )
            .frame(width: 74, height: 74)
            .shadow(color: Palette.lime.opacity(0.6), radius: 6)
            .frame(width: 116, height: 116)
            .background(Palette.raised, in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.12)))
            .shadow(color: Palette.lime.opacity(0.55), radius: 30)
            .offset(y: floats ? -4 : 0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 3).repeatForever(), value: floats)
            .accessibilityHidden(true)
    }

    /// Version, macOS and settings in a text file to attach to a bug report; no tasks or notes leave the Mac.
    private func saveDiagnostics() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Komodo Diagnostics.txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let lines =
            [
                "Komodo \(Self.version)",
                "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)",
                "Tasks: \(store.tasks.count)",
            ] + store.settings.stored.sorted { $0.key < $1.key }.map { "\($0.key) = \($0.value)" }
        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        } catch {
            Logger(subsystem: "app.komodo.Komodo", category: "settings").error("Diagnostics: \(error)")
            store.toasts.show(Toast(kind: .error, message: "Couldn't save diagnostics", detail: url.lastPathComponent))
        }
    }
}

private struct PromiseLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon.font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.green)
            configuration.title
        }
    }
}

#Preview("About") {
    SettingsAboutPage(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
        .padding(28)
        .frame(width: 864, height: 640, alignment: .top)
        .background(Palette.bg)
}
