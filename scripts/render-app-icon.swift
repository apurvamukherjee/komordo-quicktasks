// Renders every AppIcon size from one SwiftUI drawing.
// Run from the repo root: swift scripts/render-app-icon.swift
import AppKit
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

let lime = Color(hex: 0xB5F23D)
let teal = Color(hex: 0x2DD9C4)
let blue = Color(hex: 0x4D8DFF)
let violet = Color(hex: 0x8B7CFF)

// Backlog → This week → Today: the ring runs through the Board's column identities.
let spectrum = Gradient(colors: [violet, blue, teal, lime])

// Apple's macOS grid: an 824 pt body centered on a 1024 pt canvas.
let canvas: CGFloat = 1024
let bodySize: CGFloat = 824
let bodyRadius: CGFloat = 185.4
let dialCenter = CGPoint(x: 512, y: 566)
let dialRadius: CGFloat = 196
// The gap sits under the crown, centered on 12 o'clock.
let gapDegrees: Double = 72

struct Ring: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = Angle.degrees(-90 + gapDegrees / 2)
        let end = Angle.degrees(270 - gapDegrees / 2)
        path.addArc(center: dialCenter, radius: dialRadius, startAngle: start, endAngle: end, clockwise: false)
        return path
    }
}

// A check inside the timer ring: the to-do list and the timer in one mark.
struct CheckHands: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 420, y: 566))
        path.addLine(to: CGPoint(x: 484, y: 630))
        path.addLine(to: CGPoint(x: 606, y: 496))
        return path
    }
}

struct Crown: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 468, y: 268))
        path.addLine(to: CGPoint(x: 556, y: 268))
        path.move(to: CGPoint(x: 512, y: 268))
        path.addLine(to: CGPoint(x: 512, y: 312))
        return path
    }
}

struct AppIcon: View {
    // Below 64 px the hairline details blur away, so strokes thicken and the track drops out.
    let bold: Bool

    private var ringWidth: CGFloat { bold ? 96 : 72 }
    private var markWidth: CGFloat { bold ? 76 : 54 }

    private var ringFill: AngularGradient {
        AngularGradient(
            gradient: spectrum,
            center: UnitPoint(x: dialCenter.x / canvas, y: dialCenter.y / canvas),
            startAngle: .degrees(-90 + gapDegrees / 2),
            endAngle: .degrees(270 - gapDegrees / 2)
        )
    }

    private var tile: some View {
        let shape = RoundedRectangle(cornerRadius: bodyRadius, style: .continuous)
        return ZStack {
            shape.fill(
                LinearGradient(
                    colors: [Color(hex: 0x141416), Color(hex: 0x030303)], startPoint: .top, endPoint: .bottom))
            // Komodo's spotlight: a teal pool top-left, a lime ember bottom-right.
            shape.fill(
                RadialGradient(
                    colors: [teal.opacity(0.09), .clear], center: UnitPoint(x: 0.18, y: 0.08), startRadius: 0,
                    endRadius: 560))
            shape.fill(
                RadialGradient(
                    colors: [lime.opacity(0.07), .clear], center: UnitPoint(x: 0.9, y: 1), startRadius: 0,
                    endRadius: 480))
            shape.fill(
                LinearGradient(
                    colors: [.white.opacity(0.045), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.42)))
            shape.strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.2), .white.opacity(0.03), lime.opacity(0.22)], startPoint: .topLeading,
                    endPoint: .bottomTrailing),
                lineWidth: 3
            )
        }
        .frame(width: bodySize, height: bodySize)
        .shadow(color: .black.opacity(0.5), radius: 22, y: 14)
    }

    var body: some View {
        let round = StrokeStyle(lineWidth: ringWidth, lineCap: .round, lineJoin: .round)
        let mark = StrokeStyle(lineWidth: markWidth, lineCap: .round, lineJoin: .round)
        ZStack {
            tile
            ZStack {
                if !bold {
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: ringWidth)
                        .frame(width: dialRadius * 2, height: dialRadius * 2)
                        .position(dialCenter)
                }
                Ring().stroke(ringFill, style: round).blur(radius: bold ? 18 : 46).opacity(0.75)
                Ring().stroke(ringFill, style: round)
                Crown().stroke(Color(hex: 0xC7C7CC), style: StrokeStyle(lineWidth: markWidth * 0.85, lineCap: .round))
                CheckHands().stroke(Color.black.opacity(0.35), style: mark).blur(radius: 10).offset(y: 8)
                CheckHands().stroke(
                    LinearGradient(colors: [.white, Color(hex: 0xDADAE0)], startPoint: .top, endPoint: .bottom),
                    style: mark
                )
            }
            .frame(width: canvas, height: canvas)
        }
        .frame(width: canvas, height: canvas)
    }
}

enum RenderError: Error {
    case noImage(pixels: Int)
    case encodeFailed(pixels: Int)
}

@MainActor
func render(pixels: Int, to url: URL) throws {
    let renderer = ImageRenderer(content: AppIcon(bold: pixels < 64))
    renderer.scale = CGFloat(pixels) / canvas
    renderer.isOpaque = false
    guard let image = renderer.cgImage else { throw RenderError.noImage(pixels: pixels) }
    guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw RenderError.encodeFailed(pixels: pixels)
    }
    try png.write(to: url)
}

let output = URL(fileURLWithPath: "Komodo/Resources/Assets.xcassets/AppIcon.appiconset")
// A script's top level runs on the main thread, which ImageRenderer requires.
try MainActor.assumeIsolated {
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let suffix = scale == 1 ? "" : "@2x"
            try render(
                pixels: points * scale, to: output.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
        }
    }
}
