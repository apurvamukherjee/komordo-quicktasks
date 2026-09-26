#if DEBUG
    import SwiftUI

    /// Task card anatomy and states (DESIGN_SYSTEM §10.1), drawn with stand-in chips until the card component lands.
    struct TaskCardSection: View {
        var body: some View {
            GallerySection(label: "TASK CARD · ANATOMY & STATES") {
                WeightedHStack(weights: [1, 1, 1, 1], spacing: 18) {
                    column(
                        "Default · hover it",
                        "Badge · title 15/600 · chips (EST, subtasks, notes, schedule) · progress + time taken. "
                            + "Hover: spotlight, 3pt lift, action row slides in."
                    ) {
                        CardBody(chips: ["2hr 30min", "0/3", "Notes"], showsProgress: true)
                            .spotlight(SpotlightTint.today) { CardSurface() }
                    }
                    column(
                        "Focused · teal ring",
                        "System focus ring in AccentColor (teal). ⌥↑/⌥↓ move, Space toggles done."
                    ) {
                        CardBody(chips: ["2hr 30min"])
                            .spotlight(SpotlightTint.today, lifts: false) { CardSurface() }
                            .overlay(ring(Color.black, inset: -2))
                            .overlay(ring(Palette.teal, inset: -4))
                    }
                    column(
                        "Dragging · tilt + drop line",
                        "Scale 1.03, −2.5° tilt, lime underglow. 2pt teal insertion line. Target column gets a teal "
                            + "outline."
                    ) {
                        VStack(alignment: .leading, spacing: 18) {
                            CardBody(chips: ["2hr 30min"])
                                .spotlight(SpotlightTint.today, lifts: false) { CardSurface(fill: Palette.raised) }
                                .shadowDrag()
                            InsertionLine()
                        }
                    }
                    column("Done · result chip / Overdue · clock + coral", nil) {
                        VStack(spacing: 18) {
                            DoneCard()
                            OverdueCard()
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

        private func ring(_ color: Color, inset: CGFloat) -> some View {
            RoundedRectangle(cornerRadius: Radius.card - inset, style: .continuous)
                .strokeBorder(color, lineWidth: 2)
                .padding(inset)
                .allowsHitTesting(false)
        }
    }

    private struct CardBody: View {
        var title = "Review accounts"
        var chips: [String]
        var showsProgress = false

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    GalleryBadge(letter: "W", fill: Palette.lime, glyph: Palette.onAccent)
                    Text(title).font(Typography.cardTitle).foregroundStyle(Palette.textPrimary)
                }
                HStack(spacing: 6) {
                    ForEach(chips, id: \.self) { GalleryChip(text: $0) }
                }
                if showsProgress {
                    HStack(spacing: 10) {
                        Capsule().fill(Color.white.opacity(0.07)).frame(height: 4)
                        Text("00:00").font(Typography.small.monospacedDigit()).foregroundStyle(Palette.textMuted)
                    }
                    .padding(.top, 10)
                    .overlay(alignment: .top) {
                        Line()
                            .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(height: 1)
                    }
                }
            }
            .padding(Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }

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

    private struct DoneCard: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(Palette.onAccent)
                        .frame(width: 22, height: 22)
                        .background(Palette.green, in: Circle())
                    Text("Review accounts")
                        .font(Typography.cardTitle)
                        .strikethrough()
                        .foregroundStyle(Palette.textMuted)
                }
                GalleryChip(text: "12min early", tint: .green)
            }
            .padding(Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .spotlight(SpotlightTint.success, lifts: false) { CardSurface(fill: Palette.panel) }
        }
    }

    private struct OverdueCard: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    GalleryBadge(letter: "P", fill: Palette.teal, glyph: Palette.onTeal)
                    Text("Call the bank").font(Typography.cardTitle).foregroundStyle(Palette.textPrimary)
                }
                GalleryChip(text: "9:00 AM", tint: .red, icon: "clock")
            }
            .padding(Space.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .spotlight(SpotlightTint.danger, lifts: false) {
                ZStack {
                    CardSurface()
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(Palette.dangerLine.opacity(0.28), lineWidth: 1)
                }
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
