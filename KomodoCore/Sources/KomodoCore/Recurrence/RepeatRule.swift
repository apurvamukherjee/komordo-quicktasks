import Foundation

/// How a recurring task repeats (FEATURES §4.7): every `interval` days, weeks, months or years, counted from the
/// day the rule starts. Weekly rules repeat on `weekdays`; monthly and yearly ones on the start day's date.
public struct RepeatRule: Hashable, Sendable {
    public enum Unit: String, CaseIterable, Sendable {
        case day
        case week
        case month
        case year
    }

    /// The rows of the Repeat menu (DESIGN_SYSTEM §13.6). `custom` is anything the presets don't describe.
    public enum Kind: Hashable, Sendable {
        case everyDay
        case everyWeekday
        case weekly
        case monthly
        case custom
    }

    public var interval: Int
    public var unit: Unit
    /// ISO weekdays, Monday 1 through Sunday 7. Only weekly rules use them; empty means the start day's weekday.
    public var weekdays: Set<Int>
    /// The last day an occurrence may fall on; nil repeats forever.
    public var endsOn: LocalDate?

    public init(interval: Int = 1, unit: Unit, weekdays: Set<Int> = [], endsOn: LocalDate? = nil) {
        self.interval = max(1, interval)
        self.unit = unit
        self.weekdays = weekdays.filter { (1...7).contains($0) }
        self.endsOn = endsOn
    }

    public static let everyDay = RepeatRule(unit: .day)
    public static let everyWeekday = RepeatRule(unit: .week, weekdays: [1, 2, 3, 4, 5])

    public static func weekly(on weekday: Int) -> RepeatRule { RepeatRule(unit: .week, weekdays: [weekday]) }
    public static let monthly = RepeatRule(unit: .month)

    public var kind: Kind {
        guard interval == 1, endsOn == nil else { return .custom }
        switch unit {
        case .day: return .everyDay
        case .week where weekdays == [1, 2, 3, 4, 5]: return .everyWeekday
        case .week where weekdays.count <= 1: return .weekly
        case .month: return .monthly
        case .week, .year: return .custom
        }
    }

    /// Whether the rule lands on `date` when it started on `start`. Nothing lands before the start, so a rule
    /// never reaches back to days before it existed.
    public func occurs(on date: LocalDate, from start: LocalDate, calendar: Calendar) -> Bool {
        guard date >= start, endsOn.map({ date <= $0 }) ?? true else { return false }
        let first = start.startOfDay(in: calendar)
        let day = date.startOfDay(in: calendar)
        switch unit {
        case .day:
            let days = calendar.dateComponents([.day], from: first, to: day).day ?? 0
            return days % interval == 0
        case .week:
            let days = effectiveWeekdays(from: start, calendar: calendar)
            guard days.contains(date.isoWeekday(calendar: calendar)) else { return false }
            let weekStarts = (start.mondayOfWeek(calendar: calendar), date.mondayOfWeek(calendar: calendar))
            let weeks =
                calendar.dateComponents(
                    [.day], from: weekStarts.0.startOfDay(in: calendar), to: weekStarts.1.startOfDay(in: calendar)
                ).day.map { $0 / 7 } ?? 0
            return weeks % interval == 0
        case .month:
            guard date.day == start.day else { return false }
            let months = (date.year - start.year) * 12 + (date.month - start.month)
            return months % interval == 0
        case .year:
            guard date.month == start.month, date.day == start.day else { return false }
            return (date.year - start.year) % interval == 0
        }
    }

    /// Every day in `days` the rule lands on, in order.
    public func occurrences(in days: [LocalDate], from start: LocalDate, calendar: Calendar) -> [LocalDate] {
        days.filter { occurs(on: $0, from: start, calendar: calendar) }
    }

    /// Short wording for chips and the menu button: "Every day", "Weekly on Thu", "Every 2 weeks on Tue and Thu".
    public func summary(from start: LocalDate, calendar: Calendar) -> String {
        switch kind {
        case .everyDay: return "Every day"
        case .everyWeekday: return "Every weekday"
        case .weekly:
            let day = effectiveWeekdays(from: start, calendar: calendar).first ?? start.isoWeekday(calendar: calendar)
            return "Weekly on \(Self.shortName(ofWeekday: day, calendar: calendar))"
        case .monthly: return "Monthly on the \(Self.ordinal(start.day))"
        case .custom: return customSummary(from: start, calendar: calendar)
        }
    }

    /// The Custom sheet's sentence: "Every 2 weeks on Tue and Thu, no end date."
    public func sentence(from start: LocalDate, calendar: Calendar) -> String {
        let ending =
            endsOn.map { "until \($0.startOfDay(in: calendar).formatted(.dateTime.month(.abbreviated).day()))" }
            ?? "no end date"
        return "\(customSummary(from: start, calendar: calendar)), \(ending)."
    }

    private func customSummary(from start: LocalDate, calendar: Calendar) -> String {
        let every = interval == 1 ? "Every \(unit.rawValue)" : "Every \(interval) \(unit.rawValue)s"
        switch unit {
        case .day: return every
        case .week:
            let names = effectiveWeekdays(from: start, calendar: calendar).sorted()
                .map { Self.shortName(ofWeekday: $0, calendar: calendar) }
            return "\(every) on \(Self.list(names))"
        case .month: return "\(every) on the \(Self.ordinal(start.day))"
        case .year:
            let day = start.startOfDay(in: calendar).formatted(.dateTime.month(.abbreviated).day())
            return "\(every) on \(day)"
        }
    }

    private func effectiveWeekdays(from start: LocalDate, calendar: Calendar) -> Set<Int> {
        weekdays.isEmpty ? [start.isoWeekday(calendar: calendar)] : weekdays
    }

    /// "Mon" for 1 through "Sun" for 7, in the calendar's locale.
    public static func shortName(ofWeekday isoWeekday: Int, calendar: Calendar) -> String {
        let symbols = calendar.shortWeekdaySymbols
        return symbols[isoWeekday % 7]
    }

    static func ordinal(_ number: Int) -> String {
        let suffix: String
        switch (number % 10, number % 100) {
        case (_, 11...13): suffix = "th"
        case (1, _): suffix = "st"
        case (2, _): suffix = "nd"
        case (3, _): suffix = "rd"
        default: suffix = "th"
        }
        return "\(number)\(suffix)"
    }

    private static func list(_ names: [String]) -> String {
        guard names.count > 1, let last = names.last else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + last
    }
}

extension LocalDate {
    /// Monday 1 through Sunday 7, whatever the calendar's first weekday.
    public func isoWeekday(calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: startOfDay(in: calendar))
        return (weekday + 5) % 7 + 1
    }

    func mondayOfWeek(calendar: Calendar) -> LocalDate {
        adding(days: 1 - isoWeekday(calendar: calendar), calendar: calendar)
    }
}
