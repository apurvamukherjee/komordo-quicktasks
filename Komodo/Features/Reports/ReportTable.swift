import KomodoCore
import SwiftUI

/// A report table column (`.rp-th` / `.rp-tr` grids): a fixed width, or a share of what's left.
enum ReportTableColumn {
    case flexible
    case fixed(CGFloat)
}

/// Lays one row's cells out on the table's columns, each cell leading and centred vertically.
struct ReportColumnsLayout: SwiftUI.Layout {
    var columns: [ReportTableColumn]
    var spacing: CGFloat = Space.s3

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let widths = self.widths(for: proposal.width ?? 0)
        let height = zip(subviews, widths).map { $0.sizeThatFits(.init(width: $1, height: nil)).height }.max() ?? 0
        return CGSize(width: proposal.width ?? widths.reduce(0, +), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (subview, width) in zip(subviews, widths(for: bounds.width)) {
            subview.place(
                at: CGPoint(x: x, y: bounds.midY), anchor: .leading, proposal: .init(width: width, height: nil))
            x += width + spacing
        }
    }

    private func widths(for total: CGFloat) -> [CGFloat] {
        let fixed = columns.reduce(CGFloat(0)) { sum, column in
            if case .fixed(let width) = column { return sum + width }
            return sum
        }
        let flexibleCount = CGFloat(columns.filter { if case .flexible = $0 { true } else { false } }.count)
        let spare = max(0, total - fixed - spacing * CGFloat(max(0, columns.count - 1)))
        return columns.map { column in
            if case .fixed(let width) = column { return width }
            return flexibleCount > 0 ? spare / flexibleCount : 0
        }
    }
}

/// `.rp-th`: 36 pt of column labels over a hairline.
struct ReportTableHeader: View {
    var columns: [ReportTableColumn]
    var titles: [String]

    var body: some View {
        ReportColumnsLayout(columns: columns) {
            ForEach(titles, id: \.self) { title in
                Text(title)
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(Typography.Tracking.label)
                    .foregroundStyle(Palette.textMuted)
            }
        }
        .padding(.horizontal, Space.s4)
        .frame(height: 36)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }
    }
}

/// `.rp-tr`: a row on the table's columns that lights faintly under the pointer.
struct ReportTableRow<Content: View>: View {
    var columns: [ReportTableColumn]
    var tint: Color = .white
    @ViewBuilder var content: Content

    @State private var isHovered = false

    var body: some View {
        ReportColumnsLayout(columns: columns) { content }
            .font(.system(size: 13).monospacedDigit())
            .foregroundStyle(Palette.textBody)
            .padding(.horizontal, Space.s4)
            .frame(maxHeight: .infinity)
            .background(
                tint.opacity(isHovered ? 0.05 : tint == .white ? 0 : 0.045),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}

/// A list's badge and name, as the tables' List column shows it.
struct ReportListLabel: View {
    var list: TaskList?

    var body: some View {
        if let list {
            HStack(spacing: Space.s2) {
                ListBadge(letter: list.letter, color: ListColor(rawValue: list.color) ?? .lime, side: 18)
                Text(list.name).font(.system(size: 12.5)).foregroundStyle(Palette.textBody).lineLimit(1)
            }
        } else {
            Text("—").foregroundStyle(Palette.textMuted)
        }
    }
}
