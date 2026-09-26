import SwiftUI

enum Motion {
    static let fast = Animation.easeOut(duration: 0.14)
    static let base = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.22)
    static let slow = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.46)
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.62)
    static let spotlightFade = Animation.easeOut(duration: 0.32)
    static let enter = Animation.easeOut(duration: 0.62)
    static let enterStagger: TimeInterval = 0.06
}
