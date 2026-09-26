#if DEBUG
    import SwiftUI

    struct TypeSection: View {
        var body: some View {
            GallerySection(label: "TYPE · SF PRO (SYSTEM) · Typography.*") {
                VStack(alignment: .leading, spacing: 14) {
                    row("timerHero 50/700 mono·d") {
                        Text("09:27")
                            .font(Typography.timerHero)
                            .tracking(Typography.Tracking.timerHero)
                            .foregroundStyle(Palette.textPrimary)
                            .shadow(color: Palette.lime.opacity(0.4), radius: 17)
                    }
                    row("timerLarge 58/700 mono·d") {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            // The artboard draws the break countdown at 70% so the row fits.
                            Text("04:12")
                                .font(.system(size: 40, weight: .bold).monospacedDigit())
                                .tracking(-1.2)
                                .foregroundStyle(Palette.greenText)
                            Text("(break, drawn at 70%)").font(.system(size: 12)).foregroundStyle(Palette.textMuted)
                        }
                    }
                    row("display 30/800") {
                        Text("You won the day.")
                            .font(Typography.display)
                            .tracking(Typography.Tracking.display)
                            .foregroundStyle(Palette.textPrimary)
                    }
                    row("title 19/700") {
                        Text("Design review prep with Apurva")
                            .font(Typography.title)
                            .tracking(Typography.Tracking.title)
                            .foregroundStyle(Palette.textPrimary)
                    }
                    row("heading 16/700") {
                        Text("This week").font(Typography.heading).foregroundStyle(Palette.textPrimary)
                    }
                    row("cardTitle 15/600") {
                        Text("Wire NSDataDetector date parsing")
                            .font(Typography.cardTitle)
                            .foregroundStyle(Palette.textPrimary)
                    }
                    row("body 13.5/400") {
                        Text("Komodo reads your email to find meetings and deadlines.")
                            .font(Typography.body)
                            .foregroundStyle(Palette.textTertiary)
                    }
                    row("small 11.5/600") {
                        Text("2hr 30min · Sun 10:00 AM · 3/4")
                            .font(Typography.small)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    row("label 11/700 caps +0.08em") {
                        GalleryLabel("UP NEXT · SCHEDULED TODAY")
                    }
                    // SF Mono is what ships; the canvas previews used Geist Mono as a stand-in.
                    row("kbd · SF Mono 10.5") {
                        HStack(spacing: 6) {
                            ForEach(["⌘⇧B", "⌘⌥F", "⌘⇧T", "⌘F"], id: \.self) { KeyCap(keys: $0) }
                        }
                    }
                }
            }
        }

        private func row<Sample: View>(_ token: String, @ViewBuilder sample: () -> Sample) -> some View {
            HStack(alignment: .firstTextBaseline, spacing: 20) {
                Text(token)
                    .font(GalleryType.token)
                    .foregroundStyle(Palette.textBody)
                    .frame(width: 190, alignment: .leading)
                sample()
            }
        }
    }

    private struct KeyCap: View {
        var keys: String

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
            Text(keys)
                .font(Typography.kbd)
                .foregroundStyle(Palette.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.07), in: shape)
                .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        }
    }

    struct ShapeSection: View {
        private let radii: [(label: String, shape: AnyShape)] = [
            ("chip 8", AnyShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))),
            ("control 10", AnyShape(RoundedRectangle(cornerRadius: Radius.control, style: .continuous))),
            ("card 18", AnyShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))),
            ("hero 22 · sheet 20", AnyShape(RoundedRectangle(cornerRadius: Radius.hero, style: .continuous))),
            ("column 26", AnyShape(RoundedRectangle(cornerRadius: Radius.column, style: .continuous))),
            ("pill · Capsule()", AnyShape(Capsule())),
        ]
        private let steps: [CGFloat] = [Space.s1, Space.s2, Space.s3, Space.s4, Space.s5, Space.s6, Space.s8]

        var body: some View {
            GallerySection(label: "SHAPE · Radius.* · Space.* · GLOW") {
                VStack(spacing: 12) {
                    radiusRow(radii.prefix(3))
                    radiusRow(radii.dropFirst(3))
                }
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(steps, id: \.self) { step in
                        VStack(spacing: 6) {
                            Rectangle().fill(Palette.lime).frame(width: step, height: step)
                            Text("\(Int(step))").font(GalleryType.hex).foregroundStyle(Palette.textMuted)
                        }
                    }
                    Text(
                        "Card padding 16 · card gap 12 · column gutter 18 · panel padding 16 · section gap 24 · "
                            + "screen margin 32–48"
                    )
                    .font(GalleryType.use)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.leading, 12)
                }
                WeightedHStack(weights: [1, 1, 1, 1], spacing: 12) {
                    glowTile("glowLive") { $0.glowLive() }
                    glowTile("glowBreak") { $0.glowBreak() }
                    glowTile("glowDanger") { $0.glowDanger() }
                    glowTile("lift") { tile in
                        tile
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .shadow(color: .black, radius: 22, y: 20)
                    }
                }
                .padding(.top, 4)
            }
        }

        private func radiusRow(_ items: ArraySlice<(label: String, shape: AnyShape)>) -> some View {
            WeightedHStack(weights: [1, 1, 1], spacing: 12) {
                ForEach(items, id: \.label) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        item.shape.fill(Palette.raised).frame(height: 54)
                        Text(item.label).font(GalleryType.token).foregroundStyle(Palette.textBody)
                    }
                }
            }
        }

        private func glowTile<Styled: View>(
            _ label: String, style: (AnyView) -> Styled
        ) -> some View {
            let tile = AnyView(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Palette.card)
                    .frame(width: 58, height: 58))
            return VStack(spacing: 6) {
                style(tile)
                Text(label).font(GalleryType.token).foregroundStyle(Palette.textBody)
            }
            .frame(maxWidth: .infinity)
        }
    }

    #Preview("Type and shape") {
        WeightedHStack(weights: [1.25, 1], spacing: 20) {
            TypeSection()
            ShapeSection()
        }
        .padding(64)
        .frame(width: GalleryCanvas.width)
        .background(Palette.bg)
    }
#endif
