import OSLog
import SwiftUI

@main
struct KomodoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = LaunchOptions.opening(LaunchOptions.makeStore())

    var body: some Scene {
        Window("Komodo", id: "home") {
            HomeView(store: store)
                .frame(minWidth: Layout.homeMin.width, minHeight: Layout.homeMin.height)
                .onAppear { appDelegate.attach(store) }
                #if DEBUG
                    .openGalleryOnLaunchIfRequested()
                #endif
        }
        .defaultSize(LaunchOptions.windowSize ?? Layout.homeDefault)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            SettingsCommand(store: store)
            FileCommands(store: store)
            HelpCommands(store: store)
            ViewCommands(store: store)
            SidebarCommand()
            FocusCommands(store: store)
            #if DEBUG
                DebugCommands()
            #endif
        }

        MenuBarExtra {
            MenuBarMenu(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)

        #if DEBUG
            Window("Design System", id: DesignSystemGallery.windowID) {
                DesignSystemGallery()
            }
            .defaultSize(width: GalleryCanvas.width, height: 900)
        #endif
    }
}

/// ⌘, opens Komodo's own Settings window in place of the standard item.
struct SettingsCommand: Commands {
    var store: BoardStore

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { store.showSettings() }
                .keyboardShortcut(",", modifiers: .command)
        }
    }
}

/// Debug launch arguments for design reviews and screenshots:
/// - `-sampleTime artboard` anchors the sample day to the Main artboard's afternoon, and `-sampleData YES` shows it
///   around the real time. Both keep the board in memory; without them the app opens the saved database.
/// - `-homeWindowSize 1440x900` sets the Home window's first size (pair with `-ApplePersistenceIgnoreState YES`).
/// - `-openSchedule <task id>`, `-openInspector <task id>` and `-openQuickAdd YES` open those surfaces at launch,
///   so they can be captured without driving the pointer. Add `-openCustomRepeat YES` to `-openSchedule` for the
///   Custom repeat sheet.
/// - `-openPalette "design rev"` opens the command palette with a query.
/// - `-sprintDisplay sprint` counts the live card in sprints instead of the estimate, and `-sprintSeconds 20`
///   shortens sprints to watch one end.
/// - `-openFocusPanel YES` docks the Focus Panel and `-openFloatingTimer YES` shows the timer. `-focusState
///   paused|timesUp|break|celebrating|scheduled|won` puts either in one of its states (FocusStates.png).
/// - `-openTrash <count>` moves that many sample tasks to Trash and shows it; `-deleteList <list id>` also puts
///   a list there first.
/// - `-openListSheet new|edit|delete` opens the list sheet, on the selected list for edit and delete.
/// - `-openReports overview|punctuality|time|sessions` shows Reports on that tab.
/// - `-exportSessions <file.pdf|file.csv>` writes Sessions' export there at launch, to check it without the panel.
/// - `-openSettings <page>` opens Settings on general, focus, alerts, celebration, shortcuts, data or about. With
///   `data`, `-openRestore <zip>` checks that backup and shows its sheet, and `-openDeleteAll YES` the typed confirm.
enum LaunchOptions {
    @MainActor static func opening(_ store: BoardStore) -> BoardStore {
        #if DEBUG
            let defaults = UserDefaults.standard
            store.schedulingTaskID = defaults.string(forKey: "openSchedule")
            store.inspectedTaskID = defaults.string(forKey: "openInspector")
            store.isQuickAddOpen = defaults.bool(forKey: "openQuickAdd")
            store.isPaletteOpen = paletteQuery != nil
            if defaults.string(forKey: "sprintDisplay") == "sprint" { store.sprintDisplay = .sprint }
            if defaults.double(forKey: "sprintSeconds") > 0 {
                store.sprintLength = defaults.double(forKey: "sprintSeconds")
            }
            if let state = defaults.string(forKey: "focusState") { apply(state, to: store) }
            // The sample day already has a live task, so the panel opens on it rather than through Start.
            if defaults.bool(forKey: "openFocusPanel") { store.focusSurface = .panel }
            if defaults.bool(forKey: "openFloatingTimer") { store.focusSurface = .floatingTimer }
            // `-openTrash <count>` deletes that many sample tasks and shows Trash.
            let trashed = defaults.integer(forKey: "openTrash")
            if let id = defaults.string(forKey: "deleteList") { store.deleteList(id) }
            if let tab = defaults.string(forKey: "openReports").flatMap(ReportsState.Tab.init) {
                store.showReports(tab)
            }
            if let path = defaults.string(forKey: "exportSessions") {
                let url = URL(filePath: path)
                do {
                    try url.pathExtension == "pdf" ? store.writeSessionsPDF(to: url) : store.writeSessionsCSV(to: url)
                } catch {
                    Logger(subsystem: "app.komodo.Komodo", category: "reports").error("Export failed: \(error)")
                }
            }
            switch defaults.string(forKey: "openListSheet") {
            case "new": store.listSheet = .create
            case "edit": store.listSheet = store.selectedListID.map(BoardStore.ListSheet.edit)
            case "delete": store.listSheet = store.selectedListID.map(BoardStore.ListSheet.delete)
            default: break
            }
            if defaults.string(forKey: "openOnboarding") != nil { store.isOnboarding = true }
            store.showsStartTip = defaults.bool(forKey: "openStartTip")
            if trashed > 0 {
                for task in store.tasks.prefix(trashed) { store.delete(task.id) }
                store.page = .trash
            }
        #endif
        return store
    }

    #if DEBUG
        /// Drives the sample day into a Focus state through the same intents the controls use.
        @MainActor private static func apply(_ state: String, to store: BoardStore) {
            switch state {
            case "paused":
                store.togglePause()
            case "timesUp":
                // Straight to the task, since the inspector's setter locks a running estimate.
                if let live = store.liveTask {
                    store.update(live.id) { $0.estimate = max(60, live.timeTaken(at: store.now) - 134) }
                }
            case "break":
                store.takeBreak()
            case "scheduled", "won":
                if state == "won" {
                    for task in store.layout.scheduledToday { store.toggleDone(task.id) }
                }
                while store.focus.taskID != nil {
                    store.completeLive()
                    store.finishCelebration()
                }
            case "celebrating":
                store.completeLive()
            default:
                break
            }
        }
    #endif

    /// `-quietCapture YES`: the Focus Panel opens behind other apps at normal level, so a background capture
    /// doesn't cover the screen of whoever is using the Mac.
    static var capturesQuietly: Bool {
        #if DEBUG
            UserDefaults.standard.bool(forKey: "quietCapture")
        #else
            false
        #endif
    }

    /// `-openPalette <query>`: the command palette opens with this typed, `>` for commands.
    static var paletteQuery: String? {
        #if DEBUG
            UserDefaults.standard.string(forKey: "openPalette")
        #else
            nil
        #endif
    }

    /// `-openOnboarding <step>`: the first-launch sheet on plan, focus, win, notifications or today, over the
    /// sample day, and `-openStartTip YES` the tip that follows it.
    static var onboardingStep: OnboardingView.Step {
        #if DEBUG
            switch UserDefaults.standard.string(forKey: "openOnboarding") {
            case "focus": .focus
            case "win": .win
            case "notifications": .notifications
            case "today": .today
            default: .plan
            }
        #else
            .plan
        #endif
    }

    static var opensCustomRepeat: Bool {
        #if DEBUG
            UserDefaults.standard.bool(forKey: "openCustomRepeat")
        #else
            false
        #endif
    }

    /// The saved board, or in Debug the in-memory sample day for captures and previews (`-sampleTime artboard`,
    /// or `-sampleData YES` placed around the real time), which never touches the database.
    @MainActor static func makeStore() -> BoardStore {
        #if DEBUG
            if sampleTime != nil || UserDefaults.standard.bool(forKey: "sampleData") {
                return BoardSamples.store(anchoredAt: sampleTime)
            }
        #endif
        return BoardStore.persistent()
    }

    static var sampleTime: Date? {
        #if DEBUG
            UserDefaults.standard.string(forKey: "sampleTime") == "artboard" ? BoardSamples.artboardMoment : nil
        #else
            nil
        #endif
    }

    static var windowSize: CGSize? {
        #if DEBUG
            guard let text = UserDefaults.standard.string(forKey: "homeWindowSize") else { return nil }
            let parts = text.split(separator: "x").compactMap { Double($0) }
            return parts.count == 2 ? CGSize(width: parts[0], height: parts[1]) : nil
        #else
            nil
        #endif
    }
}
