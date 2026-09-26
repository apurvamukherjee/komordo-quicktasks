#if DEBUG
    import KomodoCore
    import SwiftUI

    struct SpotlightSection: View {
        private struct Demo {
            var title: String
            var use: String
            var chip: String
            var chipTint: Chip.Tint
            var tint: Color
        }

        private let demos = [
            Demo(
                title: "Today · lime", use: "Queue cards, live card, primary tiles", chip: "--sg: 181 242 61",
                chipTint: .lime, tint: SpotlightTint.today),
            Demo(
                title: "This week · blue", use: "Scheduled, calendar, info", chip: "--sg: 77 141 255",
                chipTint: .blue, tint: SpotlightTint.week),
            Demo(
                title: "Backlog · violet", use: "Parked work, report series", chip: "--sg: 139 124 255",
                chipTint: .violet, tint: SpotlightTint.backlog),
        ]

        private let notes = [
            ("fill", "Radial 300pt at the cursor, tint at 14%, under content"),
            ("border light", "1pt masked ring, radial 220pt, 95% → 22% → 0"),
            ("timing", "Fades in and out over 320ms; card lifts 3pt on a spring"),
            ("SwiftUI", "onContinuousHover → RadialGradient overlay + strokeBorder masked by a second RadialGradient"),
        ]

        var body: some View {
            GallerySection(
                label: "SIGNATURE · CURSOR SPOTLIGHT · MOVE YOUR POINTER OVER THESE", labelColor: Palette.limeText,
                ambient: Palette.lime
            ) {
                Chip("applies to every card, tile, sheet group, menu", tint: .lime)
            } content: {
                WeightedHStack(weights: [1, 1, 1], spacing: 18) {
                    ForEach(demos, id: \.title) { demo in
                        VStack(alignment: .leading, spacing: 6) {
                            Chip(demo.chip, tint: demo.chipTint)
                            Text(demo.title)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Palette.textPrimary)
                            Text(demo.use).font(GalleryType.use).foregroundStyle(Palette.textSecondary)
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .frame(height: 190, alignment: .bottom)
                        .spotlight(demo.tint) { CardSurface() }
                    }
                }
                WeightedHStack(weights: [1, 1, 1, 1], spacing: 12) {
                    ForEach(notes, id: \.0) { note in
                        GalleryCaption(token: note.0, use: note.1, tokenColor: Palette.limeText)
                            .padding(14)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .spotlight(SpotlightTint.today, radius: Radius.tile, lifts: false) {
                                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(Palette.card)
                            }
                    }
                }
            }
        }
    }

    struct MotionSection: View {
        var body: some View {
            GallerySection(label: "MOTION · Motion.* · ALL OFF UNDER REDUCE MOTION", ambient: nil) {
                Text(
                    "fast 140ms · base 220ms · slow 460ms · ease (0.2,0.8,0.2,1) · spring (0.34,1.56,0.64,1) "
                        + "≈ .spring(response: 0.4, dampingFraction: 0.62)"
                )
                .font(GalleryType.hex)
                .foregroundStyle(Palette.textMuted)
            } content: {
                WeightedHStack(weights: [1, 1, 1, 1], spacing: 16) {
                    MotionCard(
                        tint: SpotlightTint.today, title: "Focus dial",
                        detail: "60-tick radar sweep (current second white, 14-tick fading trail) · gradient arc "
                            + "with comet head · rotating blurred halo · odometer digits rolling on a spring."
                    ) { DialDemo() }
                    MotionCard(
                        tint: SpotlightTint.info, title: "Border beam + breathe",
                        detail: "AngularGradient rotated 360° over 4.5s linear; shadow breathes on 3.2s. Grey and "
                            + "still when paused, red when time's up, green on break."
                    ) { BeamDemo() }
                    MotionCard(
                        tint: SpotlightTint.today, title: "Shimmer · blur-rise",
                        detail: "Primary buttons only: sheen every 3.6s. New cards rise 12pt from 6pt blur, 620ms, "
                            + "60ms stagger."
                    ) { ShimmerRiseDemo() }
                    MotionCard(
                        tint: SpotlightTint.danger, title: "Time's up",
                        detail: "Digits go danger, shake twice (±4pt, 300ms), then count overtime up. Dial, beam "
                            + "and halo all turn red."
                    ) { TimesUpDemo() }
                }
            }
        }
    }

    private struct MotionCard<Demo: View>: View {
        var tint: Color
        var title: String
        var detail: String
        @ViewBuilder var demo: Demo

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                demo.frame(maxWidth: .infinity).frame(height: 170)
                Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(Palette.textPrimary)
                Text(detail).font(GalleryType.use).lineSpacing(2).foregroundStyle(Palette.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .spotlight(tint) { CardSurface() }
        }
    }

    /// Counts down from 09:27 of a 10-minute estimate, like the artboard's demo.
    private struct DialDemo: View {
        private static let estimate: TimeInterval = 600
        @State private var clock = FocusClock(accumulated: 33, runningSince: .now)

        var body: some View {
            FocusDial(clock: clock, estimate: Self.estimate, tone: .live, metrics: .showcase) { elapsed in
                OdometerText(
                    TimerFormat.remaining(estimate: Self.estimate, elapsed: elapsed), colon: .steady(opacity: 0.6)
                )
                .font(.system(size: 28, weight: .bold).monospacedDigit())
                .foregroundStyle(Palette.textPrimary)
                .shadow(color: Palette.lime.opacity(0.4), radius: 10)
            }
        }
    }

    private struct BeamDemo: View {
        var body: some View {
            HStack(spacing: 8) {
                Circle().fill(Palette.lime).frame(width: 7, height: 7).ping(Palette.lime)
                Text("live task").font(.system(size: 13)).foregroundStyle(Palette.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .background(Palette.panel)
            .beamBorder(.live, radius: Radius.hero)
        }
    }

    private struct ShimmerRiseDemo: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            VStack(spacing: 18) {
                Button("Start", systemImage: "play.fill") {}.buttonStyle(.komodo(.primary, size: .large))
                TimelineView(.animation(paused: reduceMotion)) { context in
                    let tile = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    Text("New card enters")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Palette.cardTop, in: tile)
                        .overlay(tile.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                        .modifier(RiseModifier(amount: reduceMotion ? 0 : Self.riseAmount(at: context.date)))
                }
            }
        }

        /// The artboard loops the enter every 2.8 s: hidden for the first 20%, risen by 45%.
        private static func riseAmount(at date: Date) -> Double {
            let loop: TimeInterval = 2.8
            let progress = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: loop) / loop
            if progress < 0.2 { return 1 }
            if progress > 0.45 { return 0 }
            let t = (progress - 0.2) / 0.25
            return 1
                - UnitCurve.bezier(
                    startControlPoint: UnitPoint(x: 0.2, y: 0.8), endControlPoint: UnitPoint(x: 0.2, y: 1)
                ).value(at: t)
        }
    }

    private struct TimesUpDemo: View {
        var body: some View {
            VStack(spacing: 14) {
                // The artboard repeats the entry shake every 2.4 s so it can be seen at rest.
                TimelineView(.periodic(from: .now, by: 2.4)) { context in
                    Text("+02:14")
                        .font(.system(size: 40, weight: .bold).monospacedDigit())
                        .foregroundStyle(Palette.dangerText)
                        .shadow(color: Palette.danger.opacity(0.6), radius: 13)
                        .shake(trigger: context.date)
                }
                HStack(spacing: 6) {
                    Chip("+5 min", tint: .red)
                    Chip("+15 min", tint: .red)
                    Chip("Done", tint: .lime)
                    Chip("Next")
                }
            }
        }
    }

    #Preview("Spotlight and motion") {
        VStack(spacing: 28) {
            SpotlightSection()
            MotionSection()
        }
        .padding(64)
        .frame(width: GalleryCanvas.width)
        .background(Palette.bg)
    }
#endif
