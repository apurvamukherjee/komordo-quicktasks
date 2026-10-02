import KomodoCore
import SwiftUI

/// Replaces the live card during a break (DESIGN_SYSTEM §10.2): a green beam, a 58 pt countdown and what's
/// up next. The countdown is derived from `endsAt`, so it stays right across sleep and redraw gaps.
struct BreakCard: View {
    var endsAt: Date
    var upNext: String
    var onSkip: () -> Void
    var onAddTwoMinutes: () -> Void

    @Environment(\.isOffscreen) private var isOffscreen

    var body: some View {
        TimelineView(.periodic(from: .now, by: Motion.tick(isMoving: true, isOffscreen: isOffscreen))) { context in
            content(remaining: max(0, endsAt.timeIntervalSince(context.date)))
        }
    }

    private func content(remaining: TimeInterval) -> some View {
        VStack(spacing: Space.s2) {
            Label("BREAK", systemImage: "cup.and.saucer.fill")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.88)
                .foregroundStyle(Palette.greenText)
            Text(TimerFormat.clock(Int(remaining.rounded(.up))))
                .font(Typography.timerLarge)
                .tracking(-1.74)
                .foregroundStyle(Palette.greenText)
                .shadow(color: Palette.green.opacity(0.55), radius: 17)
                .contentTransition(.numericText(countsDown: true))
                .accessibilityAddTraits(.updatesFrequently)
            Text("Stretch, water, eyes off the screen.")
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.textSecondary)
            (Text("Up next: ") + Text(upNext).bold().foregroundColor(Palette.textPrimary))
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.textTertiary)
            HStack(spacing: Space.s2) {
                Button(action: onSkip) { Text("Skip break").frame(maxWidth: .infinity) }
                Button(action: onAddTwoMinutes) { Text("+2 min").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.komodo(.secondary, size: .large))
            .padding(.top, 6)
        }
        .padding(.horizontal, Space.s4)
        .padding(.top, 18)
        .padding(.bottom, Space.s4)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                Palette.panel
                EllipticalGradient(
                    colors: [Palette.green.opacity(0.18), .clear], center: .top, startRadiusFraction: 0,
                    endRadiusFraction: 1.1)
            }
        }
        .beamBorder(.onBreak, radius: 24)
        .spotlight(SpotlightTint.success, radius: 24, lifts: false)
    }
}

#Preview("Break card") {
    BreakCard(endsAt: .now.addingTimeInterval(252), upNext: "Design review prep with Apurva", onSkip: {}) {}
        .frame(width: 460)
        .padding(Space.s8)
        .background(Palette.bg)
}
