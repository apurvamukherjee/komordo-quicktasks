import SwiftUI

/// The celebration on Done (DESIGN_SYSTEM §13.10, Celebration.png): a lime check pops out of a confetti burst,
/// then the result against the estimate and what's next. It ends after 2.5 s, on a click or on Esc. Under Reduce
/// Motion it's the still card: an outlined check, no confetti, pop or scale. With Fun GIF on, the hero size shows a
/// bundled GIF in the check's place; the floating card is too small for one, so it keeps the check.
struct CelebrationCard: View {
    enum Size {
        /// Takes the live card's place in the Focus Panel and the Today stage.
        case hero
        /// The 320 × 240 card above the floating timer.
        case floating
    }

    var message: String
    var nextTitle: String?
    var size: Size = .hero
    var showsGIF = false
    /// Tasks finished early or on time in a row today; the hero card shows "3 in a row today" from three.
    var inARow = 0
    var onFinish: () -> Void

    static let duration: TimeInterval = 2.5

    @State private var hasPlayed = false
    // Picked once per card, so a re-render never swaps the GIF mid-celebration.
    @State private var gif = CelebrationGIF.bundled.randomElement()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isHero: Bool { size == .hero }

    private var shownGIF: URL? { isHero && showsGIF ? gif : nil }

    var body: some View {
        let radius: CGFloat = isHero ? 24 : Space.s5
        let shape = RoundedRectangle(cornerRadius: radius - 1.5, style: .continuous)
        ZStack {
            if !reduceMotion {
                CelebrationBurst(hasPlayed: hasPlayed, isHero: isHero, originY: shownGIF == nil ? nil : 0.3)
            }
            VStack(spacing: isHero ? 10 : Space.s2) {
                if let shownGIF {
                    CelebrationGIF(url: shownGIF, isStill: reduceMotion)
                        .scaleEffect(reduceMotion || hasPlayed ? 1 : 0.8)
                        .opacity(reduceMotion || hasPlayed ? 1 : 0)
                        .animation(reduceMotion ? nil : Motion.spring, value: hasPlayed)
                        .padding(.bottom, 4)
                } else {
                    CelebrationCheck(hasPlayed: hasPlayed, side: isHero ? 92 : 42, isStill: reduceMotion)
                        .padding(.bottom, isHero ? 6 : 0)
                }
                Text(message)
                    .font(.system(size: isHero ? 22 : 14, weight: .heavy))
                    .tracking(isHero ? -0.44 : 0)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if isHero && inARow >= 3 { runChip }
                Group {
                    if let nextTitle {
                        Text("Next up: ") + Text(nextTitle).bold().foregroundColor(Palette.textPrimary)
                    } else {
                        Text("That was the last one.")
                    }
                }
                .font(.system(size: isHero ? 13 : 11))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                if isHero { countdown.padding(.top, 4) }
            }
            .padding(.horizontal, Space.s5)
        }
        .frame(maxWidth: isHero ? .infinity : 320)
        .frame(height: isHero ? 399 : 240)
        .background {
            ZStack {
                Palette.panel
                EllipticalGradient(
                    colors: [Palette.lime.opacity(reduceMotion ? 0.1 : 0.22), .clear],
                    center: UnitPoint(x: 0.5, y: 0.34), startRadiusFraction: 0, endRadiusFraction: 0.7)
            }
        }
        .clipShape(shape)
        .padding(1.5)
        .background(
            LinearGradient(
                colors: [Palette.teal, Palette.lime, Palette.amber, Palette.pink, Palette.violet],
                startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: radius, style: .continuous)
        )
        .shadow(color: Palette.lime.opacity(0.5), radius: 35)
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinish)
        .onExitCommand(perform: onFinish)
        .onAppear { hasPlayed = true }
        .task {
            // Leaving early (a click, or the task changing) cancels the wait, and nothing more happens.
            guard (try? await Task.sleep(for: .seconds(Self.duration))) != nil else { return }
            onFinish()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Starts the next task")
    }

    /// The amber pill under the message (Celebration.png ①).
    private var runChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill").font(.system(size: 11)).foregroundStyle(Palette.amber)
            Text("\(inARow) in a row today")
        }
        .font(.system(size: 12, weight: .bold).monospacedDigit())
        .foregroundStyle(Palette.amberText)
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Palette.amber.opacity(0.12), in: Capsule())
    }

    /// A line under "Next up" that fills over the 2.5 s before the next task starts.
    private var countdown: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.08))
            Capsule()
                .fill(Palette.liveGradient)
                .frame(width: hasPlayed ? 160 : 0)
                .animation(.linear(duration: Self.duration), value: hasPlayed)
        }
        .frame(width: 160, height: 3)
        .accessibilityHidden(true)
    }
}

/// The lime disc with a check that draws itself after the disc pops, or an outlined check when still.
struct CelebrationCheck: View {
    var hasPlayed: Bool
    var side: CGFloat
    var isStill: Bool

    var body: some View {
        let check = Path { path in
            path.move(to: CGPoint(x: 0.21, y: 0.52))
            path.addLine(to: CGPoint(x: 0.42, y: 0.71))
            path.addLine(to: CGPoint(x: 0.79, y: 0.29))
        }
        .applying(CGAffineTransform(scaleX: side * 0.48, y: side * 0.48))
        ZStack {
            if isStill {
                Circle().strokeBorder(Palette.lime, lineWidth: 3)
                check.stroke(
                    Palette.lime, style: StrokeStyle(lineWidth: side * 0.07, lineCap: .round, lineJoin: .round)
                )
                .frame(width: side * 0.48, height: side * 0.48)
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Palette.teal, Palette.lime], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: Palette.lime.opacity(0.85), radius: side * 0.3)
                check.trim(from: 0, to: hasPlayed ? 1 : 0)
                    .stroke(
                        Palette.onAccent, style: StrokeStyle(lineWidth: side * 0.07, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: side * 0.48, height: side * 0.48)
                    .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.48).delay(0.22), value: hasPlayed)
            }
        }
        .frame(width: side, height: side)
        .scaleEffect(isStill || hasPlayed ? 1 : 0.3)
        .opacity(isStill || hasPlayed ? 1 : 0)
        .animation(isStill ? nil : Motion.spring, value: hasPlayed)
        .accessibilityHidden(true)
    }
}

/// Two shockwave rings and a burst of confetti from behind the check, once.
struct CelebrationBurst: View {
    var hasPlayed: Bool
    var isHero: Bool
    /// Where the burst starts as a share of the height; the GIF variant bursts from higher up (`top:30%`).
    var originY: CGFloat?

    private static let colors = [
        Palette.lime, Palette.teal, Palette.blue, Palette.violet, Palette.pink, Palette.amber, Palette.green,
        Palette.danger,
    ]
    private static let count = 44

    var body: some View {
        GeometryReader { geo in
            let origin = CGPoint(x: geo.size.width / 2, y: geo.size.height * (originY ?? (isHero ? 0.4 : 0.36)))
            ZStack {
                ForEach(0..<2, id: \.self) { ring in
                    Circle()
                        .strokeBorder(ring == 0 ? Palette.lime.opacity(0.8) : Palette.teal.opacity(0.7), lineWidth: 2)
                        .frame(width: 90, height: 90)
                        .scaleEffect(hasPlayed ? 3.2 : 0.6)
                        .opacity(hasPlayed ? 0 : 1)
                        .animation(
                            .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.9).delay(Double(ring) * 0.16), value: hasPlayed
                        )
                        .position(origin)
                }
                ForEach(0..<Self.count, id: \.self) { index in
                    let piece = Self.piece(index, scale: isHero ? 1 : 0.7)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Self.colors[index % Self.colors.count])
                        .frame(width: isHero ? 7 : 6, height: isHero ? 12 : 10)
                        .rotationEffect(.degrees(hasPlayed ? piece.rotation : 0))
                        .scaleEffect(hasPlayed ? 0.5 : 1)
                        .opacity(hasPlayed ? 0 : 1)
                        .position(x: origin.x + (hasPlayed ? piece.dx : 0), y: origin.y + (hasPlayed ? piece.dy : 0))
                        .animation(.timingCurve(0.12, 0.7, 0.3, 1, duration: 1.3).delay(piece.delay), value: hasPlayed)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The canvas's spread: evenly around the circle with a little jitter, 110–200 pt out, lifted 30 pt.
    private static func piece(_ index: Int, scale: CGFloat) -> (
        dx: CGFloat, dy: CGFloat, rotation: Double, delay: Double
    ) {
        let angle = Double(index) / Double(count) * 2 * .pi + Double(index % 3) * 0.2
        let distance = Double(110 + (index * 37) % 90)
        return (
            CGFloat(cos(angle) * distance) * scale, CGFloat(sin(angle) * distance - 30) * scale,
            Double((index * 83) % 720 - 360), Double(index % 6) * 0.025
        )
    }
}

#Preview("Celebration") {
    HStack(alignment: .top, spacing: Space.s6) {
        CelebrationCard(message: "Nailed it. 12min early.", nextTitle: "Review accounts", inARow: 3) {}
            .frame(width: 312)
        CelebrationCard(message: "Done. Right on time.", nextTitle: "Prep 1:1 with Apurva", showsGIF: true) {}
            .frame(width: 312)
        CelebrationCard(message: "Done. Right on time.", nextTitle: "Prep 1:1 with Apurva", size: .floating) {}
    }
    .padding(Space.s8 * 2)
    .background(Palette.bg)
}
