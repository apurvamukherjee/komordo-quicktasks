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
                    VStack(spacing: 0) {
                        ForEach(0..<10, id: \.self) { value in
                            Text("\(value)").frame(width: geo.size.width, height: geo.size.height)
                        }
                    }
                    .offset(y: -CGFloat(digit) * geo.size.height)
                    .animation(reduceMotion ? nil : Motion.spring, value: digit)
                }
            }
            .clipped()
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
            Text(":").phaseAnimator([Beat.high, Beat.low]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in
                .easeInOut(duration: Motion.Period.colonBeat / 2)
            }
        case (.blink, false):
            // A zero-length animation after a delay holds each phase, then snaps: a step blink.
            Text(":").phaseAnimator([Beat.blinkOn, Beat.blinkOff]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in
                .linear(duration: 0).delay(Motion.Period.colonBeat / 2)
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
