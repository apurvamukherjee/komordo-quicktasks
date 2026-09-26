import SwiftUI

/// Time temperature (DESIGN_SYSTEM §2.5): what a card or control borrows from the column it sits in.
enum ColumnTone: Sendable {
    case backlog
    case week
    case today

    var spotlight: Color {
        switch self {
        case .backlog: SpotlightTint.backlog
        case .week: SpotlightTint.week
        case .today: SpotlightTint.today
        }
    }

    /// Backlog is quieter, so its titles use the body step instead of pure white.
    var titleColor: Color { self == .backlog ? Palette.textBody : Palette.textPrimary }

    var progressFill: ProgressBar.Fill {
        switch self {
        case .backlog: .solid(Palette.violet)
        case .week: .gradient(Palette.blue, Palette.cyan)
        case .today: .live
        }
    }

    var accent: Color {
        switch self {
        case .backlog: Palette.violet
        case .week: Palette.blue
        case .today: Palette.lime
        }
    }
}
