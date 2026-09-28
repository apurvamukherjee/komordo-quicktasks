import SwiftUI

/// Wraps children onto new rows like CSS `flex-wrap: wrap`, for chip rows that must never truncate a chip.
// `SwiftUI.Layout` is spelled out because the app's `Layout` token enum shadows the protocol.
struct FlowLayout: SwiftUI.Layout {
    var spacing: CGFloat = Space.s2 - 2
    var rowSpacing: CGFloat = Space.s2 - 2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + rowSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    // Neither layout defines guides. The default merges the children's, which costs a full placement pass,
    // and the window's min-size query asks for them on every frame while an effect animates.
    func explicitAlignment(
        of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
        cache: inout ()
    ) -> CGFloat? { nil }

    func explicitAlignment(
        of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
        cache: inout ()
    ) -> CGFloat? { nil }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let current = rows[rows.count - 1]
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width && !current.indices.isEmpty {
                rows.append(Row(indices: [index], width: size.width, height: size.height))
            } else {
                rows[rows.count - 1].indices.append(index)
                rows[rows.count - 1].width = needed
                rows[rows.count - 1].height = max(current.height, size.height)
            }
        }
        return rows
    }
}

#Preview("FlowLayout") {
    FlowLayout {
        ForEach(["2hr 30min", "Sun 10:00 AM", "Due Oct 10", "Every Friday", "Overdue · 9:00 AM", "Notes"], id: \.self) {
            Text($0)
                .font(Typography.small)
                .foregroundStyle(Palette.textTertiary)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: Radius.chip))
        }
    }
    .frame(width: 260)
    .padding(Space.s8)
    .background(Palette.bg)
}
