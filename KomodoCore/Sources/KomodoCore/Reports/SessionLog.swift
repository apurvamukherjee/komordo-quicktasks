import Foundation

/// The Sessions report (FEATURES §4.15): every stretch of work or break in the range, a day at a time with the
/// newest day first and each day in time order, as the canvas lists them.
public struct SessionLog: Equatable, Sendable {
    public struct Entry: Equatable, Sendable, Identifiable {
        public enum Kind: Equatable, Sendable {
            /// The task's session number counts its sessions from the first.
            case work(taskID: String, listID: String, title: String, number: Int)
            case breakTime(breakID: String)
        }

        public var kind: Kind
        public var start: Date
        /// Nil while it runs.
        public var end: Date?

        public var id: String {
            switch kind {
            case .work(let taskID, _, _, let number): "\(taskID)#\(number)"
            case .breakTime(let breakID): "break:\(breakID)"
            }
        }

        public var isBreak: Bool {
            if case .breakTime = kind { return true }
            return false
        }

        public func duration(until now: Date) -> TimeInterval { max(0, (end ?? now).timeIntervalSince(start)) }
    }

    public struct Day: Equatable, Sendable {
        public var date: LocalDate
        public var entries: [Entry]
        public var work: TimeInterval
        public var breaks: TimeInterval
    }

    public var days: [Day]

    /// Sessions are placed on the day they start.
    public init(_ data: ReportData, range: ReportRange, includesBreaks: Bool = true) {
        let interval = range.interval(calendar: data.calendar)
        var entries: [Entry] = data.tasks.flatMap { task in
            task.sessions.sorted { $0.start < $1.start }.enumerated().map { index, session in
                Entry(
                    kind: .work(taskID: task.id, listID: task.listID, title: task.title, number: index + 1),
                    start: session.start, end: session.end)
            }
        }
        if includesBreaks {
            // A break still running shows as running, like a live task, rather than with its planned end.
            entries += data.breaks.map { item in
                Entry(kind: .breakTime(breakID: item.id), start: item.start, end: item.end > data.now ? nil : item.end)
            }
        }
        let inRange = entries.filter { $0.start >= interval.start && $0.start < interval.end }
        let byDay = Dictionary(grouping: inRange) { LocalDate($0.start, calendar: data.calendar) }
        days =
            byDay
            .map { date, entries in
                let sorted = entries.sorted { $0.start < $1.start }
                return Day(
                    date: date, entries: sorted,
                    work: sorted.filter { !$0.isBreak }.reduce(0) { $0 + $1.duration(until: data.now) },
                    breaks: sorted.filter(\.isBreak).reduce(0) { $0 + $1.duration(until: data.now) })
            }
            .sorted { $0.date > $1.date }
    }

    public var entryCount: Int { days.reduce(0) { $0 + $1.entries.count } }
    public var work: TimeInterval { days.reduce(0) { $0 + $1.work } }
    /// Distinct tasks worked on.
    public var taskCount: Int {
        Set(
            days.flatMap(\.entries).compactMap { entry -> String? in
                if case .work(let taskID, _, _, _) = entry.kind { return taskID }
                return nil
            }
        ).count
    }

    /// Sessions' Export CSV: the rows as shown, oldest first, with list names looked up by id.
    public func csv(listNames: [String: String], now: Date, calendar: Calendar) -> String {
        let entries = days.reversed().flatMap(\.entries)
        return CSV.document(
            header: ["type", "task", "list", "session", "started_at", "ended_at", "minutes"],
            rows: entries.map { entry in
                let times = [
                    CSV.timestamp(entry.start.timeIntervalSince1970, calendar: calendar),
                    CSV.timestamp(entry.end?.timeIntervalSince1970, calendar: calendar),
                    CSV.minutes(entry.duration(until: now)),
                ]
                switch entry.kind {
                case .work(_, let listID, let title, let number):
                    return ["work", title, listNames[listID] ?? "", "\(number)"] + times
                case .breakTime:
                    return ["break", "", "", ""] + times
                }
            })
    }
}
