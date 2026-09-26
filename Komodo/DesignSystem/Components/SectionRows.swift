import SwiftUI

/// A section label inside a column: `UP NEXT`, `SCHEDULED TODAY 1`.
struct SectionHeader<Trailing: View>: View {
    var title: String
    var symbol: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 6) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.textMuted)
            }
            Text(title)
                .font(Typography.label)
                .tracking(Typography.Tracking.label)
                .foregroundStyle(Palette.textSecondary)
            Spacer(minLength: Space.s2)
            trailing
                .font(.system(size: 11))
                .foregroundStyle(Palette.textMuted)
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
        .accessibilityAddTraits(.isHeader)
    }
}

extension SectionHeader where Trailing == Text {
    init(_ title: String, symbol: String? = nil, detail: String) {
        self.init(title: title, symbol: symbol) { Text(detail) }
    }
}

/// The collapsed Done section at the bottom of Today: `2 Done · 2hr 30min`, expanding on click.
struct DoneSectionButton: View {
    var summary: String
    @Binding var isExpanded: Bool

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        Button {
            withAnimation(Motion.base) { isExpanded.toggle() }
        } label: {
            HStack(spacing: Space.s2) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.green)
                Text(summary)
                    .font(.system(size: 12.5).monospacedDigit())
                    .foregroundStyle(Palette.textTertiary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.textMuted)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Palette.green.opacity(isHovered ? 0.1 : 0.06), in: shape)
            .overlay(shape.strokeBorder(Palette.green.opacity(0.18), lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
    }
}

/// `+ ADD TASK` at the foot of a column: a dashed outline in the column's color, with the `N` shortcut.
struct AddTaskButton: View {
    var column: ColumnTone
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        Button(action: action) {
            HStack(spacing: Space.s2) {
                Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                Text("ADD TASK").tracking(0.6)
                Spacer()
                KeyCap("N")
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(isHovered ? Palette.textPrimary : Palette.textSecondary)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Color.white.opacity(isHovered ? 0.04 : 0), in: shape)
            .overlay(shape.strokeBorder(column.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .animation(Motion.fast, value: isHovered)
        .onHover { isHovered = $0 }
    }
}

#Preview("Section rows") {
    struct Demo: View {
        @State private var isExpanded = false

        var body: some View {
            VStack(spacing: Space.s3) {
                SectionHeader("UP NEXT", detail: "hover a card · bolt makes it live")
                SectionHeader("SCHEDULED TODAY", symbol: "calendar", detail: "1")
                AddTaskButton(column: .backlog) {}
                AddTaskButton(column: .week) {}
                DoneSectionButton(summary: "2 Done · 2hr 30min", isExpanded: $isExpanded)
            }
            .frame(width: 420)
            .padding(Space.s8)
            .background(Palette.bg)
        }
    }
    return Demo()
}
