import SwiftUI

@main
struct KomodoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Komodo", id: "home") {
            HomePlaceholderView()
                .frame(minWidth: Layout.homeMin.width, minHeight: Layout.homeMin.height)
                #if DEBUG
                    .openGalleryOnLaunchIfRequested()
                #endif
        }
        .defaultSize(Layout.homeDefault)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified(showsTitle: false))
        #if DEBUG
            .commands { DebugCommands() }
        #endif

        #if DEBUG
            Window("Design System", id: DesignSystemGallery.windowID) {
                DesignSystemGallery()
            }
            .defaultSize(width: GalleryCanvas.width, height: 900)
        #endif
    }
}
