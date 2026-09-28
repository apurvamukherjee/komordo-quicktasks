import SwiftUI

@main
struct KomodoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    // In-memory sample data until the database lands (ARCHITECTURE §16).
    @State private var store = LaunchOptions.opening(BoardSamples.store(anchoredAt: LaunchOptions.sampleTime))

    var body: some Scene {
        Window("Komodo", id: "home") {
            HomeView(store: store)
                .frame(minWidth: Layout.homeMin.width, minHeight: Layout.homeMin.height)
                #if DEBUG
                    .openGalleryOnLaunchIfRequested()
                #endif
        }
        .defaultSize(LaunchOptions.windowSize ?? Layout.homeDefault)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommand()
            #if DEBUG
                DebugCommands()
            #endif
        }

        #if DEBUG
            Window("Design System", id: DesignSystemGallery.windowID) {
                DesignSystemGallery()
            }
            .defaultSize(width: GalleryCanvas.width, height: 900)
        #endif
    }
}

/// Debug launch arguments for design reviews and screenshots:
/// - `-sampleTime artboard` anchors the sample day to the Main artboard's afternoon.
/// - `-homeWindowSize 1440x900` sets the Home window's first size (pair with `-ApplePersistenceIgnoreState YES`).
/// - `-openSchedule <task id>`, `-openInspector <task id>` and `-openQuickAdd YES` open those surfaces at launch,
///   so they can be captured without driving the pointer.
enum LaunchOptions {
    @MainActor static func opening(_ store: BoardStore) -> BoardStore {
        #if DEBUG
            store.schedulingTaskID = UserDefaults.standard.string(forKey: "openSchedule")
            store.inspectedTaskID = UserDefaults.standard.string(forKey: "openInspector")
            store.isQuickAddOpen = UserDefaults.standard.bool(forKey: "openQuickAdd")
        #endif
        return store
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
