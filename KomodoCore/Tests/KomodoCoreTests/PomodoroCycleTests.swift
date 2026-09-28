import Foundation
import Testing

@testable import KomodoCore

struct PomodoroCycleTests {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test func workAddsUpAcrossSessionsAndTheOpenOneCounts() {
        var cycle = PomodoroCycle()
        cycle.record(600)
        cycle.record(300)
        let remaining = cycle.remaining(of: 1_500, at: now, runningSince: now.addingTimeInterval(-120))
        #expect(remaining == 480)
    }

    @Test func finishingASprintStartsTheNextFromZeroAndWrapsAfterFour() {
        var cycle = PomodoroCycle()
        cycle.record(1_500)
        for _ in 1...3 { cycle.finishSprint() }
        #expect(cycle.number == 4)
        #expect(cycle.worked == 0)
        cycle.finishSprint()
        #expect(cycle.number == 1)
    }

    @Test func remainingNeverGoesNegative() {
        var cycle = PomodoroCycle()
        cycle.record(2_000)
        #expect(cycle.remaining(of: 1_500, at: now, runningSince: nil) == 0)
    }
}
