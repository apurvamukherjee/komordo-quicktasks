import Foundation
import Testing

@testable import KomodoCore

struct CelebrationCopyTests {
    @Test(
        arguments: [
            (3_600, 2_880, "Nailed it. 12min early."),
            (3_600, 3_700, "Done. Right on time."),
            (3_600, 4_080, "Done. 8min over, still counts."),
        ] as [(TimeInterval, TimeInterval, String)])
    func messageFollowsTheEstimate(estimate: TimeInterval, taken: TimeInterval, expected: String) {
        #expect(CelebrationCopy.message(estimate: estimate, taken: taken) == expected)
    }

    @Test func noEstimateJustSaysDone() {
        #expect(CelebrationCopy.message(estimate: nil, taken: 600) == "Done.")
    }
}
