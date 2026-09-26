import SwiftUI

enum Typography {
    static let timerHero = Font.system(size: 50, weight: .bold).monospacedDigit()
    static let timerLarge = Font.system(size: 58, weight: .bold).monospacedDigit()
    static let timerPill = Font.system(size: 15, weight: .bold).monospacedDigit()
    static let display = Font.system(size: 30, weight: .heavy)
    static let title = Font.system(size: 19, weight: .bold)
    static let heading = Font.system(size: 16, weight: .bold)
    static let cardTitle = Font.system(size: 15, weight: .semibold)
    static let body = Font.system(size: 13.5)
    static let small = Font.system(size: 11.5, weight: .semibold)
    static let label = Font.system(size: 11, weight: .bold)
    static let kbd = Font.system(size: 10.5, weight: .medium, design: .monospaced)

    // SwiftUI fonts can't carry tracking, so it's applied with `.tracking(_:)` at the call site.
    // Values are the canvas's em-based letter-spacing converted to points.
    enum Tracking {
        static let timerHero: CGFloat = -1.5
        static let display: CGFloat = -0.9
        static let label: CGFloat = 0.88
    }
}
