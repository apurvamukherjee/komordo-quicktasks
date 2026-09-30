import SwiftUI

/// Timer digits that roll like an odometer (DESIGN_HANDOFF §4.4): each digit is a clipped 0–9 strip
/// offset by −digit × line height on `Motion.spring`. Font and color come from the environment;
/// apply glows outside, so they aren't cut off by the per-digit clip.
struct OdometerText: View {
    enum ColonStyle {
        /// Static colon (the Foundations demo uses 60% opacity).
        case steady(opacity: Double)
        /// Running: opacity 0.9 → 0.3 → 0.9 once a second.
        case beat
        /// Paused: steps between 1 and 0.25 once a second.
        case blink
    }

    var text: String
    var colon: ColonStyle

    init(_ text: String, colon: ColonStyle = .steady(opacity: 1)) {
        self.text = text
        self.colon = colon
    }

    // Keyed from the right, so digits keep their identity (and keep rolling) when an hour digit appears.
    private var glyphs: [(id: Int, character: Character)] {
        let characters = Array(text)
        return characters.enumerated().map { (id: characters.count - $0.offset, character: $0.element) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(glyphs, id: \.id) { glyph in
                if let digit = glyph.character.wholeNumberValue {
                    OdometerDigit(digit: digit)
                } else if glyph.character == ":" {
                    OdometerColon(style: colon)
                } else {
                    Text(String(glyph.character))
                }
            }
        }
        .monospacedDigit()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct OdometerDigit: View {
    var digit: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The hidden zero sizes the cell from the environment font, so no line height is hard-coded.
        Text("0")
            .hidden()
            .overlay(alignment: .top) {
                GeometryReader { geo in
                    // The 0–9 strip rolls on Core Animation; a SwiftUI spring here kept the window laying out.
                    HostedLayer(size: geo.size) {
                        VStack(spacing: 0) {
                            ForEach(0..<10, id: \.self) { value in
                                Text("\(value)").frame(width: geo.size.width, height: geo.size.height)
                            }
                        }
                    } update: { view in
                        view.slide(to: CGFloat(digit) * geo.size.height, animated: !reduceMotion)
                    }
                }
            }
    }
}

private struct OdometerColon: View {
    var style: OdometerText.ColonStyle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Beat {
        static let high = 0.9
        static let low = 0.3
        static let blinkOn = 1.0
        static let blinkOff = 0.25
    }

    var body: some View {
        switch (style, reduceMotion) {
        case (.steady(let opacity), _):
            Text(":").opacity(opacity)
        case (_, true):
            Text(":")
        case (.beat, false):
            hosted { view in
                view.loop("beat", opacity: Beat.high) {
                    let beat = CABasicAnimation(keyPath: "opacity")
                    beat.fromValue = Beat.high
                    beat.toValue = Beat.low
                    beat.duration = Motion.Period.colonBeat / 2
                    beat.autoreverses = true
                    beat.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    return beat.loopingForever(period: Motion.Period.colonBeat)
                }
            }
        case (.blink, false):
            // Holds each opacity for half a beat, then snaps: a step blink.
            hosted { view in
                view.loop("blink", opacity: Beat.blinkOn) {
                    let blink = CAKeyframeAnimation(keyPath: "opacity")
                    blink.values = [Beat.blinkOn, Beat.blinkOff]
                    blink.keyTimes = [0, 0.5]
                    blink.calculationMode = .discrete
                    blink.duration = Motion.Period.colonBeat
                    return blink.loopingForever(period: Motion.Period.colonBeat)
                }
            }
        }
    }

    /// The colon fades on Core Animation. A hidden colon measures its cell, so the host never measures its own
    /// content on each tick.
    private func hosted(_ update: @escaping (HostedLayerView) -> Void) -> some View {
        Text(":")
            .hidden()
            .overlay {
                GeometryReader { geo in
                    HostedLayer(size: geo.size) {
                        Text(":")
                    } update: {
                        update($0)
                    }
                }
            }
    }
}

#Preview("OdometerText") {
    struct Demo: View {
        @State private var seconds = 567
        var body: some View {
            VStack(spacing: Space.s6) {
                OdometerText(String(format: "%02d:%02d", seconds / 60, seconds % 60), colon: .beat)
                    .font(Typography.timerHero)
                    .foregroundStyle(Palette.textPrimary)
                    .shadow(color: Palette.lime.opacity(0.4), radius: 17)
                OdometerText("12:07", colon: .blink)
                    .font(Typography.timerHero)
                    .foregroundStyle(Palette.textSecondary)
                Button("Tick") { seconds -= 1 }
            }
            .padding(Space.s8 * 2)
            .background(Palette.bg)
        }
    }
    return Demo()
}
