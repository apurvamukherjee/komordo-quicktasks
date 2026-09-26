import SwiftUI

/// The colors a list can wear (DESIGN_SYSTEM §2.4).
enum ListColor: String, CaseIterable, Sendable {
    case lime
    case teal
    case blue
    case pink
    case amber
    case violet
    case green
    case red

    var fill: Color {
        switch self {
        case .lime: Palette.lime
        case .teal: Palette.teal
        case .blue: Palette.blue
        case .pink: Palette.pink
        case .amber: Palette.amber
        case .violet: Palette.violet
        case .green: Palette.green
        case .red: Palette.dangerText
        }
    }

    /// A near-black of the fill's own hue. Violet, green and red borrow the closest existing dark, since
    /// the spec only defines five.
    var glyph: Color {
        switch self {
        case .lime, .green: Palette.onAccent
        case .teal: Palette.onTeal
        case .blue, .violet: Palette.onBlue
        case .pink, .red: Palette.onPink
        case .amber: Palette.onAmber
        }
    }
}

/// The letter badge that identifies a list: 22 pt on cards, 20 pt in the Today queue.
struct ListBadge: View {
    var letter: String
    var color: ListColor
    var side: CGFloat = 22

    var body: some View {
        Text(letter)
            .font(.system(size: side * 0.48, weight: .heavy))
            .foregroundStyle(color.glyph)
            .frame(width: side, height: side)
            .background(color.fill, in: RoundedRectangle(cornerRadius: side * 0.32, style: .continuous))
            .accessibilityLabel("List \(letter)")
    }
}

/// A rounded count next to a column or section title.
struct CountBadge: View {
    var count: Int
    var tint: Color
    var textColor: Color

    var body: some View {
        Text("\(count)")
            .font(.system(size: 11, weight: .bold).monospacedDigit())
            .foregroundStyle(textColor)
            .padding(.horizontal, 7)
            .frame(minWidth: 20, minHeight: 20)
            .background(tint.opacity(0.16), in: Capsule())
    }
}

/// Where a task came from, top-right on its card.
struct SourceBadge: View {
    enum Source {
        case gmail
        case calendar

        var title: String { self == .gmail ? "Gmail" : "Calendar" }
        var symbol: String { self == .gmail ? "envelope" : "calendar" }
    }

    var source: Source

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: source.symbol).font(.system(size: 9.5, weight: .semibold))
            Text(source.title)
        }
        .font(.system(size: 10.5, weight: .semibold))
        .foregroundStyle(Palette.textTertiary)
        .padding(.horizontal, 7)
        .frame(height: 22)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .fixedSize()
    }
}

#Preview("Badges") {
    VStack(alignment: .leading, spacing: Space.s4) {
        HStack(spacing: Space.s2) {
            ForEach(Array(ListColor.allCases.enumerated()), id: \.offset) { index, color in
                ListBadge(letter: String(Array("WPSLGVHR")[index]), color: color)
            }
            ListBadge(letter: "W", color: .lime, side: 20)
        }
        HStack(spacing: Space.s2) {
            CountBadge(count: 3, tint: Palette.blue, textColor: Palette.blueText)
            CountBadge(count: 12, tint: Palette.lime, textColor: Palette.limeText)
            SourceBadge(source: .gmail)
            SourceBadge(source: .calendar)
        }
    }
    .padding(Space.s8)
    .background(Palette.bg)
}
