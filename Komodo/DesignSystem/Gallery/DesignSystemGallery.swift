#if DEBUG
    import SwiftUI

    /// Debug-only replica of the Foundations artboard (design/previews/Foundations.png), so every token and
    /// effect can be checked in isolation (DESIGN_HANDOFF §3). Sizes that aren't tokens are the artboard's own
    /// layout values; nothing here ships.
    struct DesignSystemGallery: View {
        static let windowID = "design-system-gallery"

        /// Launching with `-galleryScrollTo <section>` opens the gallery at that section, so screenshots of any
        /// part can be taken without scrolling by hand.
        enum Section: String, CaseIterable {
            case principles
            case neutrals
            case accents
            case temperature
            case type
            case spotlight
            case motion
            case controls
            case cards
        }

        private static let scrollTarget = UserDefaults.standard.string(forKey: "galleryScrollTo")
            .flatMap(Section.init(rawValue:))

        var body: some View {
            ScrollViewReader { proxy in
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 28) {
                        GalleryHeader()
                        PrinciplesRow().id(Section.principles)
                        NeutralsSection().id(Section.neutrals)
                        AccentsSection().id(Section.accents)
                        TemperatureSection().id(Section.temperature)
                        WeightedHStack(weights: [1.25, 1], spacing: 20) {
                            TypeSection()
                            ShapeSection()
                        }
                        .id(Section.type)
                        SpotlightSection().id(Section.spotlight)
                        MotionSection().id(Section.motion)
                        WeightedHStack(weights: [1, 1], spacing: 20) {
                            ButtonsSection()
                            ControlsSection()
                        }
                        .id(Section.controls)
                        TaskCardSection().id(Section.cards)
                    }
                    .padding(64)
                    .frame(width: GalleryCanvas.width)
                    .background(alignment: .topLeading) { CanvasAmbient() }
                }
                .background(Palette.bg)
                .onAppear {
                    if let target = Self.scrollTarget { proxy.scrollTo(target, anchor: .top) }
                }
            }
        }
    }

    /// The two faint washes behind the artboard: teal top-left, lime top-right.
    private struct CanvasAmbient: View {
        var body: some View {
            ZStack(alignment: .topLeading) {
                EllipticalGradient(
                    stops: [.init(color: Palette.teal.opacity(0.09), location: 0), .init(color: .clear, location: 0.6)]
                )
                .frame(width: 1800, height: 1000)
                .offset(x: 144 - 900, y: -151 - 500)
                EllipticalGradient(
                    stops: [.init(color: Palette.lime.opacity(0.05), location: 0), .init(color: .clear, location: 0.6)]
                )
                .frame(width: 1600, height: 1000)
                .offset(x: 1440 - 800, y: 454 - 500)
            }
            .allowsHitTesting(false)
        }
    }

    private struct GalleryHeader: View {
        var body: some View {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        KomodoMark(size: 46).beamBorder(.live, radius: 15)
                        Text("KOMODO DESIGN SYSTEM · v1.0")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(1.04)
                            .foregroundStyle(Palette.limeText)
                    }
                    Text("Obsidian Spectrum")
                        .font(.system(size: 56, weight: .heavy))
                        .tracking(-2.24)
                        .foregroundStyle(Palette.textPrimary)
                    Text(
                        "True black for the Retina panel, color earned by interaction, light that follows your cursor, and a temperature for time: cold for someday, warm for this week, hot for now."
                    )
                    .font(.system(size: 16))
                    .lineSpacing(5)
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: 780, alignment: .leading)
                }
                Spacer()
                Text("SwiftUI · macOS 14+ · Apple silicon\ntokens → Komodo/DesignSystem/*.swift\nSep 26, 2026")
                    .font(.system(size: 12, design: .monospaced))
                    .lineSpacing(8)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Palette.textMuted)
            }
        }
    }

    private struct PrinciplesRow: View {
        private struct Principle {
            var number: String
            var title: String
            var detail: String
            var tint: Color
            var numberColor: Color
        }

        private let principles = [
            Principle(
                number: "01", title: "Black is the canvas",
                detail: "#000 window. Surfaces step up in 3–5% white. Pixels off means calm.",
                tint: Palette.lime, numberColor: Palette.limeText),
            Principle(
                number: "02", title: "Time has temperature",
                detail: "Backlog cool violet, This week blue, Today teal to lime and glowing.",
                tint: Palette.blue, numberColor: Palette.blueText),
            Principle(
                number: "03", title: "Color is earned",
                detail: "Rainbow lives in list badges, hover light and the finish line. Never decoration.",
                tint: Palette.pink, numberColor: Palette.pinkText),
            Principle(
                number: "04", title: "Numbers are heroes",
                detail: "Timers roll like an odometer. Tabular figures, never jitter.",
                tint: Palette.amber, numberColor: Palette.amberText),
            Principle(
                number: "05", title: "Light follows you",
                detail: "Every card lights up where the pointer is. Fill glow plus border light.",
                tint: Palette.teal, numberColor: Palette.tealText),
            Principle(
                number: "06", title: "Private, visibly",
                detail: "Local features wear a green shield. Claude mode says so in amber.",
                tint: Palette.green, numberColor: Palette.greenText),
        ]

        var body: some View {
            WeightedHStack(weights: Array(repeating: 1, count: principles.count), spacing: 14) {
                ForEach(principles, id: \.number) { principle in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(principle.number)
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundStyle(principle.numberColor)
                        Text(principle.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Palette.textPrimary)
                        Text(principle.detail)
                            .font(.system(size: 12.5))
                            .lineSpacing(4)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .spotlight(principle.tint) { CardSurface() }
                }
            }
        }
    }

    #Preview("Design System Gallery") {
        DesignSystemGallery()
            .frame(width: GalleryCanvas.width, height: 3780)
    }
#endif
