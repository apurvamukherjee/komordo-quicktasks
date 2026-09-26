import SwiftUI

/// The Komodo mark: a timer ring with a crown and a check inside, matching the app icon and menu bar icon
/// (DESIGN_SYSTEM §6.1; never a bolt). Drawn on a 24-unit grid like the canvas SVG and scaled to fit.
struct KomodoMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / 24
        let origin = CGPoint(x: rect.midX - 12 * unit, y: rect.midY - 12 * unit)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * unit, y: origin.y + y * unit)
        }

        var path = Path()
        // The SVG ring is dashed 36 on / 11.1 off from −58°, leaving the gap at the top for the stem.
        let circumference = 2 * CGFloat.pi * 7.5
        let sweep = 360 * 36 / circumference
        path.addArc(
            center: point(12, 13.5),
            radius: 7.5 * unit,
            startAngle: .degrees(-58),
            endAngle: .degrees(-58 + sweep),
            clockwise: false
        )
        path.move(to: point(9, 13.5))
        path.addLine(to: point(11.1, 15.6))
        path.addLine(to: point(15.1, 11.2))
        path.move(to: point(10, 2.8))
        path.addLine(to: point(14, 2.8))
        return path
    }
}

/// The app tile: the mark in `onAccent` on the live gradient.
struct KomodoMark: View {
    var size: CGFloat

    private static let cornerShare = 13.5 / 46
    private static let glyphShare = 26.0 / 46
    private static let strokeShare = 2.6 / 24

    var body: some View {
        let glyph = size * Self.glyphShare
        RoundedRectangle(cornerRadius: size * Self.cornerShare, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Palette.teal, Palette.lime], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .frame(width: size, height: size)
            .overlay {
                KomodoMarkShape()
                    .stroke(
                        Palette.onAccent,
                        style: StrokeStyle(lineWidth: glyph * Self.strokeShare, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: glyph, height: glyph)
            }
            .accessibilityLabel("Komodo")
    }
}

#Preview("KomodoMark") {
    HStack(spacing: Space.s6) {
        KomodoMark(size: 46)
        KomodoMark(size: 46).beamBorder(.live, radius: 15)
        KomodoMark(size: 128)
    }
    .padding(Space.s8 * 2)
    .background(Palette.bg)
}
