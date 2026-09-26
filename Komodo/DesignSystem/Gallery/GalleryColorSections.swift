#if DEBUG
    import SwiftUI

    struct NeutralsSection: View {
        private struct TextStep {
            var token: String
            var hex: String
            var color: Color
        }

        private let textSteps = [
            TextStep(token: "textPrimary", hex: "#FFFFFF · 18.5:1", color: Palette.textPrimary),
            TextStep(token: "textBody", hex: "#E5E5EA · 14.8:1", color: Palette.textBody),
            TextStep(token: "textTertiary", hex: "#C7C7CC · 11.0:1", color: Palette.textTertiary),
            TextStep(token: "textSecondary", hex: "#A1A1A6 · 7.2:1", color: Palette.textSecondary),
            TextStep(token: "textMuted", hex: "#8E8E93 · 5.7:1 (min)", color: Palette.textMuted),
            TextStep(token: "textDisabled", hex: "#5A5A5F · decor only", color: Palette.textDisabled),
        ]

        var body: some View {
            GallerySection(label: "COLOR · NEUTRALS & TEXT · Palette.*", ambient: nil) {
                Text("Assets.xcassets color sets · Dark + Increase Contrast")
                    .font(GalleryType.hex)
                    .foregroundStyle(Palette.textMuted)
            } content: {
                WeightedHStack(weights: Array(repeating: 1, count: 7), spacing: 12) {
                    NeutralSwatch(token: "Palette.bg", hex: "#000000", use: "Window canvas") {
                        swatch.fill(Palette.bg).overlay(swatch.strokeBorder(Palette.borderStrong, lineWidth: 1))
                    }
                    NeutralSwatch(token: "Palette.panel", hex: "#0A0A0C", use: "Columns, sections, Settings") {
                        swatch.fill(Palette.panel).overlay(swatch.strokeBorder(.white.opacity(0.08), lineWidth: 1))
                    }
                    NeutralSwatch(token: "Palette.card", hex: "#131316 · top #161619", use: "Task cards, tiles") {
                        CardSurface(radius: Radius.tile)
                    }
                    NeutralSwatch(token: "Palette.cardHover", hex: "#17171B", use: "Hovered card, rows") {
                        swatch.fill(Palette.cardHover)
                    }
                    NeutralSwatch(token: "Palette.raised", hex: "#1C1C1F", use: "Popovers, dragged card") {
                        swatch.fill(Palette.raised)
                    }
                    NeutralSwatch(token: "Palette.border", hex: "white 7%", use: "1pt dividers, card edge") {
                        HairlineSwatch(line: Palette.border)
                    }
                    NeutralSwatch(token: "Palette.borderStrong", hex: "white 14%", use: "Field outlines, hover") {
                        HairlineSwatch(line: Palette.borderStrong)
                    }
                }
                WeightedHStack(weights: Array(repeating: 1, count: textSteps.count), spacing: 12) {
                    ForEach(textSteps, id: \.token) { step in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Aa").font(.system(size: 18, weight: .bold)).foregroundStyle(step.color)
                            GalleryCaption(token: step.token, hex: step.hex)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .spotlight(Palette.teal, radius: Radius.tile, lifts: false) {
                            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Palette.card)
                        }
                    }
                }
            }
        }

        private var swatch: RoundedRectangle { RoundedRectangle(cornerRadius: Radius.tile, style: .continuous) }
    }

    private struct NeutralSwatch<Swatch: View>: View {
        var token: String
        var hex: String
        var use: String
        @ViewBuilder var swatch: Swatch

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                swatch.frame(height: 64)
                GalleryCaption(token: token, hex: hex, use: use)
            }
        }
    }

    /// Panel with a hairline edge and a second hairline 10 pt inside, showing the stroke on its own.
    private struct HairlineSwatch: View {
        var line: Color

        var body: some View {
            let outer = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
            outer.fill(Palette.panel)
                .overlay(outer.strokeBorder(line, lineWidth: 1))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.tile - 10, style: .continuous)
                        .strokeBorder(line, lineWidth: 1)
                        .padding(10)
                )
        }
    }

    struct AccentsSection: View {
        private struct Accent {
            var token: String
            var hex: String
            var use: String
            var fill: AnyShapeStyle
            var glow: Color?
        }

        private struct ListSwatch {
            var letter: String
            var name: String
            var detail: String
            var color: ListColor
        }

        private let accents = [
            Accent(
                token: "Palette.lime", hex: "#B5F23D", use: "Primary: Start, Done, selected",
                fill: AnyShapeStyle(Palette.lime), glow: Palette.lime),
            Accent(
                token: "Palette.teal", hex: "#2DD9C4", use: "AccentColor: focus rings, drop targets",
                fill: AnyShapeStyle(Palette.teal), glow: Palette.teal),
            Accent(
                token: "Palette.liveGradient", hex: "teal → lime", use: "Live beam, progress fills",
                fill: AnyShapeStyle(Palette.liveGradient), glow: Palette.lime),
            Accent(
                token: "Palette.blue", hex: "#4D8DFF", use: "This week, scheduled, calendar",
                fill: AnyShapeStyle(Palette.blue), glow: Palette.blue),
            Accent(
                token: "Palette.violet", hex: "#8B7CFF", use: "Backlog, task-hours series",
                fill: AnyShapeStyle(Palette.violet), glow: Palette.violet),
            Accent(
                token: "Palette.pink", hex: "#FF6AD5", use: "Pomodoro, “New” badges",
                fill: AnyShapeStyle(Palette.pink), glow: Palette.pink),
            Accent(
                token: "Palette.amber", hex: "#FFB547", use: "Review, late, streak, Claude warnings",
                fill: AnyShapeStyle(Palette.amber), glow: Palette.amber),
            Accent(
                token: "Palette.green", hex: "#35D483", use: "Added, Active, break, toggles on",
                fill: AnyShapeStyle(Palette.green), glow: Palette.green),
            Accent(
                token: "Palette.cyan", hex: "#38C8FF", use: "Info, update available",
                fill: AnyShapeStyle(Palette.cyan), glow: Palette.cyan),
            Accent(
                token: "Palette.danger", hex: "#FF3D5A", use: "Time's up fills, destructive",
                fill: AnyShapeStyle(Palette.danger), glow: Palette.danger),
            Accent(
                token: "Palette.dangerText", hex: "#FF6B85", use: "Danger text on cards (AA)",
                fill: AnyShapeStyle(Palette.dangerText), glow: nil),
        ]

        private let lists = [
            ListSwatch(letter: "W", name: "Work", detail: "lime · #06110A", color: .lime),
            ListSwatch(letter: "P", name: "Personal", detail: "teal · #04141A", color: .teal),
            ListSwatch(letter: "S", name: "Side project", detail: "blue · #030A1A", color: .blue),
            ListSwatch(letter: "L", name: "Launch", detail: "pink · #1A0414", color: .pink),
            ListSwatch(letter: "G", name: "Growth", detail: "amber · #1A0E02", color: .amber),
        ]

        var body: some View {
            GallerySection(label: "COLOR · SPECTRUM ACCENTS · Palette.*") {
                VStack(spacing: 12) {
                    WeightedHStack(weights: Array(repeating: 1, count: 6), spacing: 12) {
                        ForEach(accents.prefix(6), id: \.token) { accentSwatch($0) }
                    }
                    WeightedHStack(weights: Array(repeating: 1, count: 6), spacing: 12) {
                        ForEach(accents.dropFirst(6), id: \.token) { accentSwatch($0) }
                        VStack(alignment: .leading, spacing: 6) {
                            let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                            Text("Aa")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(Palette.lime)
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                                .background(Palette.onAccent, in: shape)
                                .overlay(shape.strokeBorder(Palette.lime.opacity(0.4), lineWidth: 1))
                            GalleryCaption(
                                token: "Palette.onAccent", hex: "#06110A", use: "Glyphs on lime/teal fills, never white"
                            )
                        }
                    }
                }
                WeightedHStack(weights: Array(repeating: 1, count: lists.count), spacing: 12) {
                    ForEach(lists, id: \.letter) { list in
                        HStack(spacing: 10) {
                            ListBadge(letter: list.letter, color: list.color)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(list.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Palette.textPrimary)
                                Text(list.detail).font(GalleryType.hex).foregroundStyle(Palette.textMuted)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .spotlight(list.color.fill, radius: Radius.tile, lifts: false) {
                            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Palette.card)
                        }
                    }
                }
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Palette.violet, Palette.blue, Palette.cyan, Palette.teal, Palette.lime, Palette.amber,
                                Palette.pink,
                            ],
                            startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(height: 10)
            }
        }

        private func accentSwatch(_ accent: Accent) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .fill(accent.fill)
                    .frame(height: 64)
                    .shadow(color: (accent.glow ?? .clear).opacity(0.45), radius: 12, y: 8)
                GalleryCaption(token: accent.token, hex: accent.hex, use: accent.use)
            }
        }
    }

    #Preview("Colors") {
        ScrollView {
            VStack(spacing: 28) {
                NeutralsSection()
                AccentsSection()
            }
            .padding(64)
        }
        .frame(width: GalleryCanvas.width, height: 1100)
        .background(Palette.bg)
    }
#endif
