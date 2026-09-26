#if DEBUG
    import SwiftUI

    /// Task card anatomy and states (DESIGN_SYSTEM §10.1), rendered with the real `TaskCard`.
    struct TaskCardSection: View {
        private static let defaultCard = TaskCardModel(
            id: "default", title: "Review accounts", listLetter: "W", listColor: .lime, estimate: 9_000,
            subtasks: .init(done: 0, total: 3), hasNotes: true)
        private static let plainCard = TaskCardModel(
            id: "plain", title: "Review accounts", listLetter: "W", listColor: .lime, estimate: 9_000,
            showsProgress: false)

        private let todayActions = [
            CardAction(label: "Mark done", symbol: "checkmark") {},
            CardAction(label: "Make live now", symbol: "bolt.fill", isGo: true) {},
        ]

        var body: some View {
            GallerySection(label: "TASK CARD · ANATOMY & STATES") {
                WeightedHStack(weights: [1, 1, 1, 1], spacing: 18) {
                    column(
                        "Default · hover it",
                        "Badge · title 15/600 · chips (EST, subtasks, notes, schedule) · progress + time taken. "
                            + "Hover: spotlight, 3pt lift, action row slides in."
                    ) {
                        TaskCard(model: Self.defaultCard, column: .today, actions: todayActions)
                    }
                    column(
                        "Focused · teal ring",
                        "System focus ring in AccentColor (teal). ⌥↑/⌥↓ move, Space toggles done."
                    ) {
                        TaskCard(model: Self.plainCard, column: .today, isFocused: true)
                    }
                    column(
                        "Dragging · tilt + drop line",
                        "Scale 1.03, −2.5° tilt, lime underglow. 2pt teal insertion line. Target column gets a teal "
                            + "outline."
                    ) {
                        VStack(alignment: .leading, spacing: 18) {
                            TaskCard(model: Self.plainCard, column: .today, isDragging: true)
                            InsertionLine()
                        }
                    }
                    column("Done · result chip / Overdue · clock + coral", nil) {
                        VStack(spacing: 18) {
                            TaskCard(model: TaskCardSamples.doneEarly, column: .today)
                            TaskCard(model: TaskCardSamples.overdue, column: .today)
                        }
                    }
                }
            }
        }

        private func column<Card: View>(
            _ title: String, _ detail: String?, @ViewBuilder card: () -> Card
        ) -> some View {
            VStack(alignment: .leading, spacing: 10) {
                card()
                Text(title).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                if let detail {
                    Text(detail).font(GalleryType.use).lineSpacing(2).foregroundStyle(Palette.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    /// The 2 pt teal line with a dot that marks where a dragged card will land. The Board will own the real one.
    private struct InsertionLine: View {
        var body: some View {
            Capsule()
                .fill(Palette.teal)
                .frame(height: 3)
                .shadow(color: Palette.teal.opacity(0.9), radius: 6)
                .overlay(alignment: .leading) {
                    Circle().fill(Palette.teal).frame(width: 9, height: 9).offset(x: -3)
                }
        }
    }

    #Preview("Task cards") {
        TaskCardSection()
            .padding(64)
            .frame(width: GalleryCanvas.width)
            .background(Palette.bg)
    }
#endif
