import SwiftUI

/// Columns that share the width by weight, like CSS `minmax(0, 1fr) minmax(0, 1.52fr)`, and share
/// the tallest child's height so tiles in a row line up. The Board uses `Layout.columnWeights`.
// `SwiftUI.Layout` is spelled out because the app's `Layout` token enum shadows the protocol.
struct WeightedHStack: SwiftUI.Layout {
    var weights: [CGFloat]
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? idealWidth(subviews)
        let widths = columnWidths(total: width, count: subviews.count)
        let height =
            zip(subviews, widths)
            .map { subview, columnWidth in
                subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
            }
            .max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = columnWidths(total: bounds.width, count: subviews.count)
        var x = bounds.minX
        for (subview, columnWidth) in zip(subviews, widths) {
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: columnWidth, height: bounds.height)
            )
            x += columnWidth + spacing
        }
    }

    private func weight(at index: Int) -> CGFloat {
        weights.indices.contains(index) ? weights[index] : 1
    }

    private func columnWidths(total: CGFloat, count: Int) -> [CGFloat] {
        guard count > 0 else { return [] }
        let available = max(0, total - spacing * CGFloat(count - 1))
        let sum = (0..<count).map(weight(at:)).reduce(0, +)
        return (0..<count).map { available * weight(at: $0) / sum }
    }

    private func idealWidth(_ subviews: Subviews) -> CGFloat {
        let widths = subviews.map { $0.sizeThatFits(.unspecified).width }
        return widths.reduce(0, +) + spacing * CGFloat(max(0, subviews.count - 1))
    }
}

#Preview("WeightedHStack · Board columns") {
    WeightedHStack(weights: Layout.columnWeights, spacing: Space.columnGutter) {
        ForEach(["Backlog", "This week", "Today"], id: \.self) { name in
            Text(name)
                .font(Typography.heading)
                .foregroundStyle(Palette.textPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.panel, in: RoundedRectangle(cornerRadius: Radius.column))
        }
    }
    .frame(width: 900, height: 200)
    .padding(Space.s8)
    .background(Palette.bg)
}
