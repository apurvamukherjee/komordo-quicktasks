import Foundation

/// Focused time per day and the streak of days with a task done, for the sidebar's Focused today card.
public enum FocusHistory {
    /// Seconds of work on each day, splitting sessions that cross midnight.
    public static func daily(_ tasks: [TaskItem], days: [LocalDate], now: Date, calendar: Calendar) -> [TimeInterval] {
        days.map { day in
            let start = day.startOfDay(in: calendar)
            let end = day.adding(days: 1, calendar: calendar).startOfDay(in: calendar)
            return tasks.reduce(0) { sum, task in
                sum
                    + task.sessions.reduce(0) { partial, session in
                        let from = max(session.start, start)
                        let to = min(session.end ?? now, end)
                        return partial + max(0, to.timeIntervalSince(from))
                    }
            }
        }
    }

    /// Consecutive days with at least one task done, ending today (FEATURES §4.13). Today doesn't break the streak
    /// until it's over, so the count holds through the morning.
    public static func streak(_ tasks: [TaskItem], today: LocalDate, calendar: Calendar) -> Int {
        let doneDays = Set(tasks.compactMap { $0.completedAt.map { LocalDate($0, calendar: calendar) } })
        var day = doneDays.contains(today) ? today : today.adding(days: -1, calendar: calendar)
        var count = 0
        while doneDays.contains(day) {
            count += 1
            day = day.adding(days: -1, calendar: calendar)
        }
        return count
    }
}
