import SwiftUI

/// A thin, glowing progress bar: 4 pt under task cards, 6 pt elsewhere (DESIGN_SYSTEM §9).
struct ProgressBar: View {
    enum Fill {
        /// Teal → lime, for Today and anything live.
        case live
        case solid(Color)
        case gradient(Color, Color)

        var style: AnyShapeStyle {
            switch self {
            case .live: AnyShapeStyle(Palette.liveGradient)
            case .solid(let color): AnyShapeStyle(color)
            case .gradient(let from, let to):
                AnyShapeStyle(LinearGradient(colors: [from, to], startPoint: .leading, endPoint: .trailing))
            }
        }

        var glow: Color {
            switch self {
            case .live: Palette.lime.opacity(0.7)
            case .solid(let color): color
            case .gradient(let from, _): from
            }
        }
    }

    var value: Double
    var fill: Fill = .live
    var height: CGFloat = 4

    var body: some View {
        let clamped = min(1, max(0, value))
        Capsule()
            .fill(Color.white.opacity(0.07))
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    if clamped > 0 {
                        Capsule()
                            .fill(fill.style)
                            .frame(width: max(height, geo.size.width * clamped))
                            .shadow(color: fill.glow, radius: 5)
                    }
                }
            }
            .accessibilityElement()
            .accessibilityValue(Text("\(Int(clamped * 100)) percent"))
    }
}

/// The 30 pt subtask dial in a card's corner: a ring filling as subtasks are checked, with `1/3` inside.
struct SubtaskRing: View {
    var done: Int
    var total: Int
    var tint: Color

    var body: some View {
        let progress = total > 0 ? Double(done) / Double(total) : 0
        ZStack {
            Circle().stroke(Color.white.opacity(0.1), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(done)/\(total)")
                .font(.system(size: 8.5, weight: .bold).monospacedDigit())
                .foregroundStyle(Palette.textTertiary)
        }
        .frame(width: 22, height: 22)
        .frame(width: 30, height: 30)
        .accessibilityElement()
        .accessibilityLabel("Subtasks \(done) of \(total)")
    }
}

#Preview("Progress") {
    VStack(alignment: .leading, spacing: Space.s4) {
        ProgressBar(value: 0.22, fill: .solid(Palette.violet))
        ProgressBar(value: 0.15, fill: .gradient(Palette.blue, Palette.cyan))
        ProgressBar(value: 0.6)
        ProgressBar(value: 0.8, height: 6)
        ProgressBar(value: 0)
        HStack(spacing: Space.s3) {
            SubtaskRing(done: 1, total: 3, tint: Palette.blue)
            SubtaskRing(done: 2, total: 3, tint: Palette.lime)
            SubtaskRing(done: 0, total: 5, tint: Palette.violet)
        }
    }
    .frame(width: 280)
    .padding(Space.s8)
    .background(Palette.bg)
}
