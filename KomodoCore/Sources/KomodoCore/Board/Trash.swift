import Foundation

/// How long deleted tasks and lists wait in Trash (FEATURES §4.20).
public enum Trash {
    public static let keptDays = 30

    /// Days until an item is gone for good, counted in calendar days: 30 on the day it's deleted, 1 on its last.
    public static func daysLeft(deletedAt: Date, now: Date, calendar: Calendar) -> Int {
        let elapsed =
            calendar.dateComponents(
                [.day], from: calendar.startOfDay(for: deletedAt), to: calendar.startOfDay(for: now)
            )
            .day ?? 0
        return keptDays - elapsed
    }

    public static func isExpired(deletedAt: Date, now: Date, calendar: Calendar) -> Bool {
        daysLeft(deletedAt: deletedAt, now: now, calendar: calendar) <= 0
    }
}
