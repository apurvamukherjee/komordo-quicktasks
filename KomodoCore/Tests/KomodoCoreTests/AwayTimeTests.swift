import Foundation
import Testing

@testable import KomodoCore

struct AwayTimeTests {
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func at(_ minutes: Double) -> Date { start.addingTimeInterval(minutes * 60) }

    private func task(_ sessions: [WorkSession]) -> TaskItem {
        TaskItem(id: "t", listID: "work", title: "Design review", bucket: .today, rank: 0, sessions: sessions)
    }

    @Test func asksOnlyAfterFiveMinutesAway() {
        #expect(!AwayTime.shouldAsk(sleptAt: at(10), wokeAt: at(15)))
        #expect(AwayTime.shouldAsk(sleptAt: at(10), wokeAt: at(57)))
    }

    @Test func discardingSplitsTheRunningSessionAroundTheGap() {
        let discarded = AwayTime.discarding(from: at(10), to: at(57), in: task([WorkSession(start: at(0))]))
        #expect(discarded.sessions == [WorkSession(start: at(0), end: at(10)), WorkSession(start: at(57))])
        #expect(discarded.timeTaken(at: at(60)) == 13 * 60)
    }

    @Test func discardingTrimsSessionsPausedSinceAndLeavesOthersAlone() {
        let sessions = [
            WorkSession(start: at(-30), end: at(-20)),
            WorkSession(start: at(0), end: at(59)),
        ]
        let discarded = AwayTime.discarding(from: at(10), to: at(57), in: task(sessions))
        #expect(
            discarded.sessions == [
                WorkSession(start: at(-30), end: at(-20)), WorkSession(start: at(0), end: at(10)),
                WorkSession(start: at(57), end: at(59)),
            ])
    }
}
