import KomodoCore
import SwiftUI

/// The tile above Today (DESIGN_SYSTEM §10.3): tasks done, what's left, time focused, and when the day should
/// end, over one segment per task. The current task's segment pulses.
struct DayMeter: View {
    var done: Int
    var total: Int
    var estimateLeft: TimeInterval
    var focused: TimeInterval
    /// Projected from the queue (ARCHITECTURE §4.2), e.g. "6:40 PM".
    var endsAround: String

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            // Stats sit beside the count when there's room and wrap under it in a narrow column.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom) {
                    count
                    Spacer(minLength: Space.s3)
                    stats
                }
                VStack(alignment: .leading, spacing: 10) {
                    count
                    stats
                }
            }
            HStack(spacing: 4) {
                ForEach(0..<max(total, 1), id: \.self) { index in
                    DaySegment(state: segmentState(index))
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, Space.s4)
        .spotlight(SpotlightTint.today, radius: Space.s4, lifts: false) {
            TileSurface(radius: Space.s4)
        }
        .accessibilityElement(children: .combine)
    }

    private var count: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            (Text("\(done)") + Text("/\(total)").fontWeight(.semibold).foregroundColor(Palette.textMuted))
                .font(.system(size: 28, weight: .heavy).monospacedDigit())
                .tracking(-0.84)
                .foregroundStyle(Palette.textPrimary)
            Text("DONE")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.88)
                .foregroundStyle(Palette.limeText)
        }
    }

    private var stats: some View {
        HStack(spacing: 18) {
            stat("EST LEFT", DurationFormat.short(estimateLeft))
            stat("FOCUSED", DurationFormat.short(focused))
            stat("ENDS AROUND", endsAround, color: Palette.limeText)
        }
        .fixedSize()
    }

    private func stat(_ label: String, _ value: String, color: Color = Palette.textPrimary) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Palette.textMuted)
            Text(value)
                .font(.system(size: 14, weight: .bold).monospacedDigit())
                .foregroundStyle(color)
        }
    }

    private func segmentState(_ index: Int) -> DaySegment.State {
        if index < done { return .done }
        if index == done && done < total { return .current }
        return .upcoming
    }
}

private struct DaySegment: View {
    enum State {
        case done
        case current
        case upcoming
    }

    var state: State
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        switch state {
        case .done:
            shape.fill(Palette.liveGradient)
                .frame(height: 7)
                .shadow(color: Palette.lime.opacity(0.5), radius: 4)
        case .upcoming:
            shape.fill(Color.white.opacity(0.1)).frame(height: 7)
        case .current:
            if reduceMotion {
                shape.fill(Palette.lime.opacity(0.5)).frame(height: 7)
            } else {
                // A layer animation: a SwiftUI one would tick the whole Board's view graph every frame.
                LayerEffect<PulseLayerView> { $0.configure(color: Palette.lime.opacity(0.5), cornerRadius: 4) }
                    .frame(height: 7)
            }
        }
    }
}

/// The current segment, fading between 50% and full over the ping period.
private final class PulseLayerView: EffectLayerView {
    private let fill = CALayer()

    required init(frame: NSRect) {
        super.init(frame: frame)
        fill.cornerCurve = .continuous
        layer?.addSublayer(fill)
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 0.5
        pulse.toValue = 1
        pulse.duration = Motion.Period.ping / 2
        pulse.autoreverses = true
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        fill.add(pulse.loopingForever(period: Motion.Period.ping), forKey: "pulse")
    }

    required init?(coder: NSCoder) { nil }

    func configure(color: Color, cornerRadius: CGFloat) {
        withoutActions {
            fill.backgroundColor = cgColor(color)
            fill.cornerRadius = cornerRadius
        }
    }

    override func layout() {
        super.layout()
        withoutActions { fill.frame = bounds }
    }
}

#Preview("Day meter") {
    VStack(spacing: Space.s4) {
        DayMeter(done: 2, total: 7, estimateLeft: 16_200, focused: 7_800, endsAround: "6:40 PM")
        DayMeter(done: 7, total: 7, estimateLeft: 0, focused: 20_400, endsAround: "5:12 PM")
    }
    .frame(width: 480)
    .padding(Space.s8)
    .background(Palette.bg)
}
