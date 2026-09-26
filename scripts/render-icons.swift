// Renders Komodo's icons from SwiftUI drawings: the layers of AppIcon.icon (Xcode flattens it for macOS 14–15)
// and the menu bar template images.
// Run from the repo root: swift scripts/render-icons.swift
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

// Icon Composer masks the full 1024 canvas, so the layers scale the 824 pt body up to fill it and leave the
// glow, rim and shadow to Liquid Glass.
struct RingLayer: View {
    var body: some View {
        Ring()
            .stroke(
                AngularGradient(
                    gradient: spectrum,
                    center: UnitPoint(x: dialCenter.x / canvas, y: dialCenter.y / canvas),
                    startAngle: .degrees(-90 + gapDegrees / 2),
                    endAngle: .degrees(270 - gapDegrees / 2)
                ),
                style: StrokeStyle(lineWidth: 72, lineCap: .round)
            )
            .frame(width: canvas, height: canvas)
            .scaleEffect(canvas / bodySize)
    }
}

struct MarkLayer: View {
    var body: some View {
        ZStack {
            Crown().stroke(Color(hex: 0xC7C7CC), style: StrokeStyle(lineWidth: 46, lineCap: .round))
            CheckHands().stroke(.white, style: StrokeStyle(lineWidth: 54, lineCap: .round, lineJoin: .round))
        }
        .frame(width: canvas, height: canvas)
        .scaleEffect(canvas / bodySize)
    }
}

// The menu bar mark on the same 24-unit grid as KomodoMarkShape in the app. Template images are black plus
// alpha, so the states differ by shape: a check when idle, a filled wedge while running, a cut-in dot when
// Google needs reconnecting.
enum MenuBarState: CaseIterable {
    case idle, running, attention

    var assetName: String {
        switch self {
        case .idle: "MenuBarIcon"
        case .running: "MenuBarIconRunning"
        case .attention: "MenuBarIconAttention"
        }
    }
}

struct MenuBarGlyph: Shape {
    let state: MenuBarState

    func path(in rect: CGRect) -> Path {
        let unit = rect.width / 24
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * unit, y: y * unit) }
        let circumference = 2 * CGFloat.pi * 7.5
        var path = Path()
        path.addArc(
            center: point(12, 13.5), radius: 7.5 * unit, startAngle: .degrees(-58),
            endAngle: .degrees(-58 + 360 * 36 / circumference), clockwise: false)
        path.move(to: point(10, 2.8))
        path.addLine(to: point(14, 2.8))
        path.move(to: point(12, 2.8))
        path.addLine(to: point(12, 5.2))
        if state != .running {
            path.move(to: point(9, 13.5))
            path.addLine(to: point(11.1, 15.6))
            path.addLine(to: point(15.1, 11.2))
        }
        return path
    }
}

struct MenuBarIcon: View {
    let state: MenuBarState
    let size: CGFloat

    var body: some View {
        let unit = size / 24
        ZStack {
            MenuBarGlyph(state: state)
                .stroke(.black, style: StrokeStyle(lineWidth: 2.2 * unit, lineCap: .round, lineJoin: .round))
            if state == .running {
                Path { path in
                    path.move(to: CGPoint(x: 12 * unit, y: 13.5 * unit))
                    path.addArc(
                        center: CGPoint(x: 12 * unit, y: 13.5 * unit), radius: 4.3 * unit, startAngle: .degrees(-90),
                        endAngle: .degrees(20), clockwise: false)
                    path.closeSubpath()
                }
                .fill(.black)
            }
            if state == .attention {
                Circle().fill(.black).frame(width: 10 * unit, height: 10 * unit).position(x: 19.2 * unit, y: 5.2 * unit)
                    .blendMode(.destinationOut)
                Circle().fill(.black).frame(width: 6 * unit, height: 6 * unit)
                    .position(x: 19.2 * unit, y: 5.2 * unit)
            }
        }
        .compositingGroup()
        .frame(width: size, height: size)
    }
}

enum RenderError: Error {
    case noImage(URL)
    case encodeFailed(URL)
}

@MainActor
func render(_ view: some View, scale: CGFloat, to url: URL) throws {
    let renderer = ImageRenderer(content: view)
    renderer.scale = scale
    renderer.isOpaque = false
    guard let image = renderer.cgImage else { throw RenderError.noImage(url) }
    guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw RenderError.encodeFailed(url)
    }
    try png.write(to: url)
}

let resources = URL(fileURLWithPath: "Komodo/Resources")
let catalog = resources.appendingPathComponent("Assets.xcassets")
// A script's top level runs on the main thread, which ImageRenderer requires.
try MainActor.assumeIsolated {
    let layers = resources.appendingPathComponent("AppIcon.icon/Assets")
    try render(RingLayer(), scale: 1, to: layers.appendingPathComponent("ring.png"))
    try render(MarkLayer(), scale: 1, to: layers.appendingPathComponent("mark.png"))

    for state in MenuBarState.allCases {
        let imageSet = catalog.appendingPathComponent("\(state.assetName).imageset")
        for scale in [1, 2] {
            let suffix = scale == 1 ? "" : "@2x"
            try render(
                MenuBarIcon(state: state, size: 18), scale: CGFloat(scale),
                to: imageSet.appendingPathComponent("\(state.assetName)\(suffix).png"))
        }
    }
}
