import SwiftUI

@main
struct KomodoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Komodo", id: "home") {
            HomePlaceholderView()
                .frame(minWidth: Layout.homeMin.width, minHeight: Layout.homeMin.height)
        }
        .defaultSize(Layout.homeDefault)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified(showsTitle: false))
    }
}
