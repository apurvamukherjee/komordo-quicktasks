import Foundation

/// Sleeping with a task running (ARCHITECTURE §4.3): the session carries on through sleep, and past five minutes
/// away the app asks whether to count that time or discard it.
public enum AwayTime {
    public static let asksAfter: TimeInterval = 5 * 60

    public static func shouldAsk(sleptAt: Date, wokeAt: Date) -> Bool {
        wokeAt.timeIntervalSince(sleptAt) > asksAfter
    }

    /// Discard: the time between sleep and wake comes out of every session that spans it, splitting a session
    /// that runs across. Works whether the task is still running or was paused before the answer came.
    public static func discarding(from sleptAt: Date, to wokeAt: Date, in task: TaskItem) -> TaskItem {
        var task = task
        task.sessions = task.sessions.flatMap { session -> [WorkSession] in
            let end = session.end ?? .distantFuture
            guard session.start < wokeAt, end > sleptAt else { return [session] }
            var kept: [WorkSession] = []
            if session.start < sleptAt { kept.append(WorkSession(start: session.start, end: sleptAt)) }
            if end > wokeAt { kept.append(WorkSession(start: wokeAt, end: session.end)) }
            return kept
        }
        return task
    }
}
