import Foundation
import Testing

@testable import KomodoCore

struct TimeTakenTests {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func task(_ minutes: [Double], open: Bool = false) -> TaskItem {
        var start = now.addingTimeInterval(-10_000)
        var sessions: [WorkSession] = minutes.map { length in
            defer { start = start.addingTimeInterval(length * 60 + 60) }
            return WorkSession(start: start, end: start.addingTimeInterval(length * 60))
        }
        if open { sessions.append(WorkSession(start: now.addingTimeInterval(-60))) }
        return TaskItem(id: "t", listID: "work", title: "t", bucket: .today, rank: 0, sessions: sessions)
    }

    @Test func addingTimeAddsASessionEndingNow() {
        var item = task([10])
        item.setTimeTaken(25 * 60, at: now)
        #expect(item.timeTaken(at: now) == 25 * 60)
        #expect(item.sessions.last?.end == now)
    }

    @Test func removingTimeTrimsTheLatestSessionsFirst() {
        var item = task([10, 5])
        item.setTimeTaken(8 * 60, at: now)
        #expect(item.timeTaken(at: now) == 8 * 60)
        #expect(item.sessions.count == 1)
    }

    @Test func zeroClearsEverySession() {
        var item = task([10, 5])
        item.setTimeTaken(0, at: now)
        #expect(item.sessions.isEmpty)
    }

    @Test func aRunningTaskKeepsItsTime() {
        var item = task([10], open: true)
        item.setTimeTaken(0, at: now)
        #expect(item.timeTaken(at: now) == 11 * 60)
    }
}
