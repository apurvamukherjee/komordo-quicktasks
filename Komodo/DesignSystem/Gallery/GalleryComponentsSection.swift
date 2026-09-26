#if DEBUG
    import KomodoCore
    import SwiftUI

    /// Components the Foundations artboard doesn't show, drawn from Main, System and BoardStates, so they can be
    /// checked in one place before the screens use them.
    struct ComponentsSection: View {
        @State private var openedAt = Date.now
        @State private var isDoneExpanded = false

        var body: some View {
            GallerySection(label: "COMPONENTS · FOCUS, QUEUE & FEEDBACK") {
                WeightedHStack(weights: [1, 1, 1], spacing: 18) {
                    labeled("Live task · running") {
                        LiveTaskCard(
                            model: LiveTaskSamples.designReview,
                            clock: FocusClock(accumulated: 3_033, runningSince: openedAt), actions: ControlBarActions())
                    }
                    labeled("Live task · time's up") {
                        LiveTaskCard(
                            model: LiveTaskSamples.designReview,
                            clock: FocusClock(accumulated: 3_734, runningSince: openedAt), actions: ControlBarActions())
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        labeled("Day meter") {
                            DayMeter(done: 2, total: 7, estimateLeft: 16_200, focused: 7_800, endsAround: "6:40 PM")
                        }
                        labeled("Break") {
                            BreakCard(
                                endsAt: openedAt.addingTimeInterval(252), upNext: "Design review prep with Apurva",
                                onSkip: {}, onAddTwoMinutes: {})
                        }
                    }
                }
                WeightedHStack(weights: [1, 1, 1], spacing: 18) {
                    labeled("Queue · sections") {
                        VStack(spacing: Space.s3) {
                            SectionHeader("UP NEXT", detail: "hover a card · bolt makes it live")
                            QueueCard(
                                model: TaskCardSamples.dataDetector, position: 2, startsAt: "2:23 PM", onDone: {},
                                onMakeLive: {})
                            AddTaskButton(column: .today) {}
                            SectionHeader("SCHEDULED TODAY", symbol: "calendar", detail: "1")
                            DoneSectionButton(summary: "2 Done · 2hr 30min", isExpanded: $isDoneExpanded)
                        }
                    }
                    labeled("Banners") {
                        VStack(spacing: Space.s3) {
                            Banner(
                                tone: .danger, message: "Google disconnected. Reconnect to keep adding events.",
                                action: .init(title: "Reconnect") {}, onClose: {})
                            Banner(
                                tone: .warning,
                                message:
                                    "You're offline. Everything still works, and Gmail will catch up when you're back.",
                                action: .init(title: "Dismiss") {})
                            Banner(
                                tone: .info, message: "Komodo 1.1 is ready.",
                                action: .init(title: "Install and Relaunch") {}, onClose: {})
                        }
                    }
                    labeled("Toasts · popover") {
                        VStack(alignment: .leading, spacing: Space.s3) {
                            ToastView(
                                toast: Toast(
                                    message: "Moved to Today", detail: "Wireframes",
                                    action: .init(title: "Undo", shortcut: "⌘Z") {})
                            ) {}
                            ToastView(toast: Toast(kind: .error, message: "Backup failed", detail: "Folder not found"))
                            {
                            }
                            PopoverSample()
                        }
                    }
                }
            }
        }

        private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
            VStack(alignment: .leading, spacing: 10) {
                GalleryLabel(title.uppercased(), color: Palette.textMuted)
                content()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private struct PopoverSample: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(["Move to Today", "Schedule…", "Repeat…", "Delete"], id: \.self) { item in
                    Text(item)
                        .font(Typography.body)
                        .foregroundStyle(item == "Delete" ? Palette.dangerText : Palette.textPrimary)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                }
            }
            .padding(6)
            .frame(width: 220)
            .popoverSurface()
        }
    }

    #Preview("Components") {
        ComponentsSection()
            .padding(64)
            .frame(width: GalleryCanvas.width)
            .background(Palette.bg)
    }
#endif
