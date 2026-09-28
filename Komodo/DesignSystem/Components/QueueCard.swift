import SwiftUI

/// A card in the Today queue (DESIGN_SYSTEM §10.1): its place in line, a drag grip, and a lime projection of
/// when it will start. Hovering offers Done and the bolt that makes it live.
struct QueueCard: View {
    var model: TaskCardModel
    var position: Int
    /// Projected from the queue above it (ARCHITECTURE §4.2), e.g. "2:23 PM".
    var startsAt: String
    var onDone: () -> Void
    var onMakeLive: () -> Void
    var isFocused = false

    @State private var isHovered = false

    private var chips: some View {
        ForEach(model.chips(includingSubtasks: true)) { Chip($0.text, tint: $0.tint, icon: $0.icon) }
    }

    private var startsChip: some View { Chip("starts ~\(startsAt)", tint: .lime) }

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            VStack(spacing: 6) {
                Text("\(position)")
                    .font(.system(size: 13, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Palette.textBody)
                    .frame(width: 30, height: 30)
                    .background(
                        Color.white.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.textDisabled)
                    .accessibilityLabel("Drag to reorder")
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    Text(model.title)
                        .font(Typography.cardTitle)
                        .lineSpacing(3)
                        .foregroundStyle(Palette.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ListBadge(letter: model.listLetter, color: model.listColor, side: 20)
                }
                // The start projection stays top-right and the chips wrap beside it. A `ViewThatFits` choosing
                // between an HStack and a FlowLayout of equal ideal width flipped on every pass, rebuilding the
                // chips and re-laying out the Board each frame.
                HStack(alignment: .top, spacing: 6) {
                    FlowLayout { chips }.layoutPriority(1)
                    Spacer(minLength: 0)
                    startsChip
                }
                HStack(spacing: 10) {
                    ProgressBar(value: model.progress, fill: .live)
                    Text(model.timeTakenLabel)
                        .font(Typography.small.monospacedDigit())
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.leading, 14)
        .padding(.trailing, Space.s4)
        .overlay(alignment: .topTrailing) {
            if isHovered {
                CardActionRow(actions: [
                    CardAction(label: "Mark done", symbol: "checkmark", perform: onDone),
                    CardAction(label: "Make live now", symbol: "bolt.fill", isGo: true, perform: onMakeLive),
                ])
                .padding(Space.s3)
                .transition(.opacity.combined(with: .offset(x: 8)))
            }
        }
        .spotlight(SpotlightTint.today) { CardSurface() }
        .overlay { if isFocused { FocusRing(radius: Radius.card) } }
        .onHover { hovering in withAnimation(Motion.base) { isHovered = hovering } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(position). \(model.title), starts about \(startsAt)")
    }
}

#Preview("Queue cards") {
    VStack(spacing: Space.s3) {
        QueueCard(
            model: TaskCardSamples.dataDetector, position: 2, startsAt: "2:23 PM", onDone: {}, onMakeLive: {})
        QueueCard(
            model: TaskCardSamples.reviewAccounts, position: 3, startsAt: "3:23 PM", onDone: {}, onMakeLive: {})
    }
    .frame(width: 520)
    .padding(Space.s8)
    .background(Palette.bg)
}
