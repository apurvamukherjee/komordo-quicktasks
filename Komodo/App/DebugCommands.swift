#if DEBUG
    import SwiftUI

    /// A Debug menu that exists only in Debug builds, for tools like the design system gallery.
    struct DebugCommands: Commands {
        @Environment(\.openWindow) private var openWindow

        var body: some Commands {
            CommandMenu("Debug") {
                Button("Design System Gallery") { openWindow(id: DesignSystemGallery.windowID) }
                    .keyboardShortcut("g", modifiers: [.command, .option, .shift])
            }
        }
    }

    /// Opens the gallery at launch when the app is started with `-design-gallery`, so screenshots and
    /// design reviews don't need a trip through the menu.
    private struct OpenGalleryOnLaunch: ViewModifier {
        static let argument = "-design-gallery"
        @Environment(\.openWindow) private var openWindow

        func body(content: Content) -> some View {
            content.task {
                if ProcessInfo.processInfo.arguments.contains(Self.argument) {
                    openWindow(id: DesignSystemGallery.windowID)
                }
            }
        }
    }

    extension View {
        func openGalleryOnLaunchIfRequested() -> some View {
            modifier(OpenGalleryOnLaunch())
        }
    }
#endif
