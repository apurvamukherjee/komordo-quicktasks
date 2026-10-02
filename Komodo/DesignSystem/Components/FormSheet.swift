import SwiftUI

/// `.ds-sheet` (DataSheets.png): a 42 pt tinted icon beside an 18 pt title, the body, and the buttons trailing.
/// Backup's sheets and the list sheets share it. An integration's sheet shows the provider's letter instead, on
/// the neutral tile its card uses (the token sheet in DataSheets.dc.html).
struct FormSheet<Title: View, Content: View, Actions: View>: View {
    var symbol: String
    var tint: Color
    var glyph: Color
    var letter: String?
    @ViewBuilder var title: Title
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: Space.s3) {
                if let letter {
                    let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
                    Text(letter)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(Palette.textPrimary)
                        .frame(width: 42, height: 42)
                        .background(Palette.raised, in: shape)
                        .overlay(shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(glyph)
                        .frame(width: 42, height: 42)
                        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
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
