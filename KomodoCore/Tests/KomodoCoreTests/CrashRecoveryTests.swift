import Foundation
import Testing

@testable import KomodoCore

struct CrashRecoveryTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func task(_ id: String, sessions: [WorkSession]) -> TaskItem {
        TaskItem(id: id, listID: "work", title: id, bucket: .today, rank: 0, sessions: sessions)
    }

    @Test func endsTheOpenSessionAtTheLastHeartbeat() {
        let heartbeat = start.addingTimeInterval(600)
        let tasks = [
            task("done", sessions: [WorkSession(start: start, end: start.addingTimeInterval(60))]),
            task("live", sessions: [WorkSession(start: start)]),
        ]
        let result = CrashRecovery.closingOpenSessions(in: tasks, lastHeartbeat: heartbeat)
        #expect(result.interrupted?.id == "live")
        #expect(result.tasks[1].sessions[0].end == heartbeat)
        #expect(result.tasks[0] == tasks[0])
    }

    @Test func countsNothingWithoutALaterHeartbeat() {
        let stale = start.addingTimeInterval(-3_600)
        let result = CrashRecovery.closingOpenSessions(
            in: [task("live", sessions: [WorkSession(start: start)])], lastHeartbeat: stale)
        #expect(result.tasks[0].sessions[0].end == start)
    }

    @Test func leavesAClosedBoardAlone() {
        let tasks = [task("done", sessions: [WorkSession(start: start, end: start.addingTimeInterval(60))])]
        let result = CrashRecovery.closingOpenSessions(in: tasks, lastHeartbeat: nil)
        #expect(result.interrupted == nil)
        #expect(result.tasks == tasks)
    }
}
