import AppKit
import KomodoCore
import SwiftUI

/// The menu bar item (DESIGN_SYSTEM §14.1, System.png ①–②): the mark, and while a timer runs the filled wedge and
/// the time left, unless Settings turns the time off. It always exists, so it also reopens Home on ⌘⇧B.
struct MenuBarLabel: View {
    var store: BoardStore

    @Environment(\.openWindow) private var openWindow
    /// A `TimelineView` here makes the status item re-render endlessly, so a task moves the time on instead.
    @State private var now = Date.now

    var body: some View {
        let time = Self.time(store: store, at: now)
        HStack(spacing: 4) {
            Image(time == nil ? "MenuBarIcon" : "MenuBarIconRunning")
            if let time, store.settings.showsMenuBarTimer {
                Text(time).monospacedDigit()
            }
        }
        .task {
            while (try? await Task.sleep(for: .seconds(1))) != nil { now = .now }
        }
        // With a menu bar item, SwiftUI stops opening Home by itself at launch, so the item opens it.
        .onAppear { openWindow(id: "home") }
        .onChange(of: store.homeRequests) {
            openWindow(id: "home")
            NSApp.activate()
        }
        .accessibilityLabel("Komodo")
    }

    /// The pill's time while a task or break counts; nil otherwise.
    @MainActor static func time(store: BoardStore, at date: Date) -> String? {
        let clock = store.liveTask.map { store.focusClock(for: $0) }
        switch PillState(store: store, clock: clock, at: date).kind {
        case .live(_, _, let time), .onBreak(let time, _): return time
        case .done, .waiting, .idle: return nil
        }
    }
}

/// The menu: the live task with Pause, Done and Skip while one runs, then Open Komodo, Settings and Quit.
/// Gmail → Calendar's rows join it with that milestone.
struct MenuBarMenu: View {
    var store: BoardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let live = store.liveTask {
                LiveSection(store: store, title: live.title)
                separator
            }
            MenuBarRow(title: "Open Komodo", symbol: "sidebar.left", shortcut: shortcutLabel) { store.showHome() }
            MenuBarRow(title: "Settings…", symbol: "slider.horizontal.3", shortcut: "⌘,") { store.showSettings() }
            MenuBarRow(title: "Quit Komodo", symbol: "power", shortcut: "⌘Q") { NSApp.terminate(nil) }
        }
        .padding(5)
        .frame(width: 304)
        .spotlight(store.liveTask == nil ? Palette.teal : Palette.lime, radius: Radius.tile, lifts: false) {
            Palette.panel
        }
        .preferredColorScheme(.dark)
    }

    private var shortcutLabel: String { store.settings.shortcut(for: .showKomodo).label }

    private var separator: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1).padding(.vertical, 5).padding(.horizontal, 4)
    }
}

private struct LiveSection: View {
    var store: BoardStore
    var title: String

    var body: some View {
        let clock = store.liveTask.map { store.focusClock(for: $0) }
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let state = PillState(store: store, clock: clock, at: context.date)
            VStack(spacing: 9) {
                HStack(spacing: Space.s2) {
                    Image(systemName: clock?.isRunning == true ? "play.fill" : "pause.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.lime)
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(MenuBarLabel.time(store: store, at: context.date) ?? "")
                        .font(.system(size: 14, weight: .bold).monospacedDigit())
                        .foregroundStyle(Palette.limeText)
                        .shadow(color: Palette.lime.opacity(0.55), radius: 7)
                }
                ProgressBar(value: state.progress)
                HStack(spacing: 6) {
                    Button(clock?.isRunning == true ? "Pause" : "Resume", action: store.togglePause)
                        .buttonStyle(KomodoButtonStyle(kind: .secondary, size: .small))
                    Button("Done", action: store.completeLive)
                        .buttonStyle(KomodoButtonStyle(kind: .primary, size: .small))
                    Button("Skip", action: store.skip)
                        .buttonStyle(KomodoButtonStyle(kind: .secondary, size: .small))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 9)
            .padding(.top, 7)
            .padding(.bottom, 9)
        }
    }
}

/// `.sy-mi`: an icon, the title and its shortcut, lit on hover. Choosing one closes the menu's window.
private struct MenuBarRow: View {
    var title: String
    var symbol: String
    var shortcut: String
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            NSApp.keyWindow?.close()
            action()
        } label: {
            HStack(spacing: Space.s2) {
                Image(systemName: symbol).font(.system(size: 12)).frame(width: 16)
                Text(title).font(.system(size: 13))
                Spacer()
                Text(shortcut).font(.system(size: 12)).foregroundStyle(Palette.textMuted)
            }
            .foregroundStyle(Palette.textBody)
            .padding(.horizontal, Space.s2)
            .frame(height: 26)
            .background(
                Color.white.opacity(isHovered ? 0.08 : 0),
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

#Preview("Menu bar menu") {
    MenuBarMenu(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
}
