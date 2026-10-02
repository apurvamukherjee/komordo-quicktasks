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
        /// The break's breathing circle: 4 s in, 4 s out (FocusPanel.dc.html).
        static let breath: TimeInterval = 8
        /// The calm card's glow and its orbiting dot, when only timed tasks are left.
        static let calmGlow: TimeInterval = 5.5
        static let orbit: TimeInterval = 16
        /// The won card's sparks, each a quarter of the cycle after the last (FocusStates.dc.html).
        static let twinkle: TimeInterval = 2.4
    }
}
