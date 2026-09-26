import SwiftUI

// Color sets live in Assets.xcassets (DESIGN_SYSTEM §2). `ColorResource` symbols are spelled out
// because `Color(.green)` and friends are ambiguous with the AppKit system colors.
enum Palette {
    static let bg = Color(ColorResource.bg)
    static let panel = Color(ColorResource.panel)
    static let card = Color(ColorResource.card)
    static let cardTop = Color(ColorResource.cardTop)
    static let cardHover = Color(ColorResource.cardHover)
    static let raised = Color(ColorResource.raised)
    static let border = Color.white.opacity(0.07)
    static let borderStrong = Color.white.opacity(0.14)

    static let textPrimary = Color(ColorResource.textPrimary)
    static let textBody = Color(ColorResource.textBody)
    static let textTertiary = Color(ColorResource.textTertiary)
    static let textSecondary = Color(ColorResource.textSecondary)
    static let textMuted = Color(ColorResource.textMuted)
    static let textDisabled = Color(ColorResource.textDisabled)

    static let lime = Color(ColorResource.lime)
    static let teal = Color(ColorResource.teal)
    static let blue = Color(ColorResource.blue)
    static let violet = Color(ColorResource.violet)
    static let pink = Color(ColorResource.pink)
    static let amber = Color(ColorResource.amber)
    static let green = Color(ColorResource.green)
    static let cyan = Color(ColorResource.cyan)
    static let danger = Color(ColorResource.danger)
    static let dangerText = Color(ColorResource.dangerText)
    static let onAccent = Color(ColorResource.onAccent)

    // The lighter step used for text inside tinted chips (DESIGN_SYSTEM §2.2).
    static let limeText = Color(ColorResource.limeText)
    static let tealText = Color(ColorResource.tealText)
    static let blueText = Color(ColorResource.blueText)
    static let violetText = Color(ColorResource.violetText)
    static let pinkText = Color(ColorResource.pinkText)
    static let amberText = Color(ColorResource.amberText)
    static let greenText = Color(ColorResource.greenText)
    static let redText = Color(ColorResource.redText)

    static let liveGradient = LinearGradient(colors: [teal, lime], startPoint: .leading, endPoint: .trailing)
}

enum SpotlightTint {
    static let today = Palette.lime
    static let week = Palette.blue
    static let backlog = Palette.violet
    static let success = Palette.green
    static let review = Palette.amber
    static let danger = Palette.danger
    static let info = Palette.teal
}
