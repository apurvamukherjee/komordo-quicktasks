import Foundation

/// A session still open at launch means Komodo stopped without quitting (ARCHITECTURE §4.3). Quitting closes the
/// live session, so only a crash, a force quit or a power cut leaves one.
public enum CrashRecovery {
    /// Ends every open session at the last heartbeat, or where it began when no heartbeat came after it, so
    /// the time Komodo wasn't running isn't counted. Returns the task that was running, to offer a resume.
    public static func closingOpenSessions(
        in tasks: [TaskItem], lastHeartbeat: Date?
    ) -> (tasks: [TaskItem], interrupted: TaskItem?) {
        var interrupted: TaskItem?
        let closed = tasks.map { task -> TaskItem in
            guard let open = task.sessions.lastIndex(where: { $0.end == nil }) else { return task }
            var task = task
            let start = task.sessions[open].start
            task.sessions[open].end = max(start, lastHeartbeat ?? start)
            interrupted = task
            return task
        }
        return (closed, interrupted)
    }
}
