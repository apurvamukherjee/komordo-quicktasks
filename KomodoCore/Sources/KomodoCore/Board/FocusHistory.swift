import Foundation

/// Focused time per day and the current streak, for the sidebar's Focused today card.
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

    /// Consecutive days with any focus, ending today. A day with no focus yet doesn't break the streak until
    /// it's over, so the count holds through the morning.
    public static func streak(_ tasks: [TaskItem], today: LocalDate, now: Date, calendar: Calendar) -> Int {
        var count = 0
        var day = today
        if daily(tasks, days: [today], now: now, calendar: calendar)[0] == 0 {
            day = today.adding(days: -1, calendar: calendar)
        }
        while daily(tasks, days: [day], now: now, calendar: calendar)[0] > 0 {
            count += 1
            day = day.adding(days: -1, calendar: calendar)
        }
        return count
    }
}
