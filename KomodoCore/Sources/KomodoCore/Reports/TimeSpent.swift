import Foundation

/// The Time spent report (DESIGN_SYSTEM §13.13): hours by list, each with its tasks, most first.
public struct TimeSpent: Equatable, Sendable {
    public struct Item: Equatable, Sendable {
        public var id: String
        public var title: String
        public var time: TimeInterval
    }

    public struct List: Equatable, Sendable {
        public var listID: String
        public var time: TimeInterval
        public var tasks: [Item]
    }

    public var lists: [List]

    public init(_ data: ReportData, range: ReportRange) {
        let interval = range.interval(calendar: data.calendar)
        let byList = Dictionary(grouping: data.tasks, by: \.listID)
        lists =
            byList
            .map { listID, tasks in
                let items =
                    tasks
                    .map { task in
                        Item(
                            id: task.id, title: task.title,
                            time: task.sessions.reduce(0) { $0 + data.overlap($1.start, $1.end, interval) })
                    }
                    .filter { $0.time > 0 }
                    .sorted { $0.time > $1.time }
                return List(listID: listID, time: items.reduce(0) { $0 + $1.time }, tasks: items)
            }
            .filter { $0.time > 0 }
            .sorted { ($0.time, $1.listID) > ($1.time, $0.listID) }
    }

    public var total: TimeInterval { lists.reduce(0) { $0 + $1.time } }
    public var taskCount: Int { lists.reduce(0) { $0 + $1.tasks.count } }

    /// A list's or task's share of the total, 0 to 1.
    public func share(of time: TimeInterval) -> Double { total > 0 ? time / total : 0 }
}
