import SwiftUI

/// `.ds-sheet` (DataSheets.png): a 42 pt tinted icon beside an 18 pt title, the body, and the buttons trailing.
/// Backup's sheets and the list sheets share it.
struct FormSheet<Title: View, Content: View, Actions: View>: View {
    var symbol: String
    var tint: Color
    var glyph: Color
    @ViewBuilder var title: Title
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: Space.s3) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(glyph)
                    .frame(width: 42, height: 42)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                title
                    .font(.system(size: 18, weight: .heavy))
                    .tracking(-0.36)
                    .foregroundStyle(Palette.textPrimary)
            }
            content
                .font(.system(size: 13))
                .foregroundStyle(Palette.textBody)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Space.s2) {
                Spacer()
                actions
            }
        }
        .padding(22)
        .frame(width: Layout.sheetFormWidth)
        .background(Palette.raised)
    }
}
