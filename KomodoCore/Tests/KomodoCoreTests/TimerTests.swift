import Foundation
import Testing

@testable import KomodoCore

struct FocusClockTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test func pausedClockReturnsAccumulated() {
        let clock = FocusClock(accumulated: 90)
        #expect(!clock.isRunning)
        #expect(clock.elapsed(at: start.addingTimeInterval(3600)) == 90)
    }

    @Test func runningClockAddsTimeSinceStart() {
        let clock = FocusClock(accumulated: 90, runningSince: start)
        #expect(clock.elapsed(at: start.addingTimeInterval(30)) == 120)
    }

    @Test func clockNeverRunsBackwards() {
        let clock = FocusClock(accumulated: 10, runningSince: start)
        #expect(clock.elapsed(at: start.addingTimeInterval(-5)) == 10)
    }
}

struct TimerFormatTests {
    @Test(arguments: [
        (0, "00:00"),
        (567, "09:27"),
        (3599, "59:59"),
        (3600, "1:00:00"),
        (3623, "1:00:23"),
        (-134, "+02:14"),
        (-3661, "+1:01:01"),
    ])
    func clock(seconds: Int, expected: String) {
        #expect(TimerFormat.clock(seconds) == expected)
    }

    @Test func remainingRoundsUpUntilTheEstimate() {
        #expect(TimerFormat.remaining(estimate: 600, elapsed: 0.2) == "10:00")
        #expect(TimerFormat.remaining(estimate: 600, elapsed: 599.5) == "00:01")
        #expect(TimerFormat.remaining(estimate: 600, elapsed: 600) == "00:00")
        #expect(TimerFormat.remaining(estimate: 600, elapsed: 600.5) == "00:00")
        #expect(TimerFormat.remaining(estimate: 600, elapsed: 734) == "+02:14")
    }
}
