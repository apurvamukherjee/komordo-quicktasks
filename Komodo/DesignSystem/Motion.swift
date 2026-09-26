import SwiftUI

enum Motion {
    static let fast = Animation.easeOut(duration: 0.14)
    static let base = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.22)
    static let slow = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.46)
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.62)
    static let spotlightFade = Animation.easeOut(duration: 0.32)
    static let enter = Animation.easeOut(duration: 0.62)
    static let enterStagger: TimeInterval = 0.06

    /// Loop lengths of the continuous effects (DESIGN_SYSTEM §5).
    enum Period {
        static let beam: TimeInterval = 4.5
        static let breathe: TimeInterval = 3.2
        static let halo: TimeInterval = 7
        static let sheen: TimeInterval = 3.6
        static let ping: TimeInterval = 1.6
        static let colonBeat: TimeInterval = 1
        static let shake: TimeInterval = 0.3
    }
}
