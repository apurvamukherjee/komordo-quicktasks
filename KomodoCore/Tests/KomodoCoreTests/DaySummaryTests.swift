import Foundation
import Testing

@testable import KomodoCore

struct DaySummaryTests {
    private let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func done(estimate: TimeInterval?, taken: TimeInterval) -> TaskItem {
        let start = now.addingTimeInterval(-taken)
        return TaskItem(
            id: UUID().uuidString, listID: "work", title: "t", bucket: .today, rank: 0, estimate: estimate,
            completedAt: now, sessions: [WorkSession(start: start, end: now)])
    }

    @Test func sortsTasksAgainstTheirEstimates() {
        let summary = DaySummary(
            doneToday: [
                done(estimate: 3_600, taken: 2_400),
                done(estimate: 3_600, taken: 3_780),
                done(estimate: 1_800, taken: 2_400),
            ], now: now)
        #expect(summary == DaySummary(early: 1, onTime: 1, late: 1))
        #expect(summary.onEstimate == 2.0 / 3.0)
    }

    @Test func tenPercentEitherWayIsOnTime() {
        let summary = DaySummary(
            doneToday: [done(estimate: 1_000, taken: 900), done(estimate: 1_000, taken: 1_100)], now: now)
        #expect(summary.onTime == 2)
    }

    @Test func tasksWithoutAnEstimateAreLeftOut() {
        let summary = DaySummary(doneToday: [done(estimate: nil, taken: 600)], now: now)
        #expect(summary.measured == 0)
        #expect(summary.onEstimate == nil)
    }

    /// Finished `order` minutes into the day, so later calls finish later.
    private func finished(_ order: Int, estimate: TimeInterval?, taken: TimeInterval) -> TaskItem {
        var task = done(estimate: estimate, taken: taken)
        task.completedAt = now.addingTimeInterval(Double(order - 100) * 60)
        return task
    }

    @Test func aRunCountsBackFromTheLatestFinish() {
        let tasks = [
            finished(1, estimate: 600, taken: 300),
            finished(2, estimate: 600, taken: 900),
            finished(3, estimate: 600, taken: 600),
            finished(4, estimate: 600, taken: 400),
        ]
        #expect(DaySummary.onEstimateRun(tasks.shuffled(), now: now) == 2)
    }

    @Test func aLateFinishEndsTheRun() {
        let tasks = [finished(1, estimate: 600, taken: 300), finished(2, estimate: 600, taken: 900)]
        #expect(DaySummary.onEstimateRun(tasks, now: now) == 0)
    }

    @Test func tasksWithoutAnEstimateDontBreakTheRun() {
        let tasks = [
            finished(1, estimate: 600, taken: 600),
            finished(2, estimate: nil, taken: 900),
            finished(3, estimate: 600, taken: 500),
        ]
        #expect(DaySummary.onEstimateRun(tasks, now: now) == 2)
    }
}

extension DaySummary {
    fileprivate init(early: Int, onTime: Int, late: Int) {
        self.init(doneToday: [], now: .distantPast)
        self.early = early
        self.onTime = onTime
        self.late = late
    }
}
