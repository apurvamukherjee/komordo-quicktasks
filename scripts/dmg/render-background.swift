// Renders the .dmg window background in Komodo's colors. Run only when the art changes; the PNGs are committed,
// so a release build needs nothing but macOS.
// Run from the repo root: swift scripts/dmg/render-background.swift
import AppKit
import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

let lime = Color(hex: 0xB5F23D)
let teal = Color(hex: 0x2DD9C4)

// A 540 x 400 pt window. Finder snaps dropped icons to its grid, so these are where the icons land in a built
// image, not the positions make-dmg.sh asks for: the arrow follows the icons.
let size = CGSize(width: 540, height: 400)
let iconY: CGFloat = 218
let appX: CGFloat = 145
let aliasX: CGFloat = 395
// Finder draws the icon labels in black on a custom background, so each label gets a light plate to sit on.
let labelY: CGFloat = 298

struct Background: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(hex: 0x0E0F11), Color(hex: 0x060607)], startPoint: .top, endPoint: .bottom)
            // The Today column's glow, teal into lime, hanging from the top edge as it does on the Board.
            EllipticalGradient(
                colors: [teal.opacity(0.22), lime.opacity(0.08), .clear], center: UnitPoint(x: 0.5, y: -0.05),
                startRadiusFraction: 0, endRadiusFraction: 0.75)
            VStack(spacing: 7) {
                HStack(spacing: 9) {
                    Circle().fill(lime).frame(width: 9, height: 9).shadow(color: lime.opacity(0.9), radius: 6)
                    Text("Komodo").font(.system(size: 25, weight: .heavy)).tracking(-0.5)
                        .foregroundStyle(.white.opacity(0.95))
                }
                Text("DRAG TO APPLICATIONS TO INSTALL")
                    .font(.system(size: 9, weight: .semibold)).tracking(2)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(width: size.width)
            .padding(.top, 62)
            arrow
            labelPlate(width: 92, color: lime.opacity(0.92)).offset(x: appX - 46, y: labelY - 10)
            labelPlate(width: 98, color: .white.opacity(0.82)).offset(x: aliasX - 49, y: labelY - 10)
            Text("Not notarized yet. If macOS blocks it, see the release notes.")
                .font(.system(size: 8.5)).tracking(0.3)
                .foregroundStyle(.white.opacity(0.3))
                .frame(width: size.width)
                .offset(y: 356)
        }
        .frame(width: size.width, height: size.height)
    }

    private func labelPlate(width: CGFloat, color: Color) -> some View {
        Capsule().fill(color).frame(width: width, height: 20)
    }

    // Starts and ends clear of the 128 pt icons, so neither sits on top of it.
    private var arrow: some View {
        let start = appX + 62
        let end = aliasX - 62
        let head: CGFloat = 22
        return ZStack(alignment: .topLeading) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [teal.opacity(0.15), teal.opacity(0.7), lime], startPoint: .leading,
                        endPoint: .trailing)
                )
                .frame(width: end - start - head + 4, height: 7)
                .offset(x: start, y: iconY - 3.5)
            Path { path in
                path.move(to: CGPoint(x: end - head, y: iconY - 17))
                path.addLine(to: CGPoint(x: end, y: iconY))
                path.addLine(to: CGPoint(x: end - head, y: iconY + 17))
                path.closeSubpath()
            }
            .fill(lime)
            .shadow(color: lime.opacity(0.7), radius: 8)
        }
    }
}

@MainActor func write(scale: CGFloat, to path: String) throws {
    let renderer = ImageRenderer(content: Background())
    renderer.scale = scale
    guard let image = renderer.cgImage else { throw CocoaError(.fileWriteUnknown) }
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let data = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    try data.write(to: URL(filePath: path))
}

MainActor.assumeIsolated {
    do {
        try write(scale: 1, to: "scripts/dmg/background.png")
        try write(scale: 2, to: "scripts/dmg/background@2x.png")
        print("wrote scripts/dmg/background.png and @2x")
    } catch {
        print("couldn't render: \(error)")
        exit(1)
    }
}
