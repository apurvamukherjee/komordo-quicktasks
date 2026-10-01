import Foundation

/// One occurrence of a calendar event, as the app reads it from macOS Calendar.
public struct CalendarEvent: Equatable, Sendable {
    /// Stable for this occurrence across launches: the event's external ID plus its start.
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var notes: String?
    public var location: String?
    public var url: URL?
    /// The calendar's name, shown as where the task came from.
    public var calendarTitle: String
    /// Accepted, organized by the user, or without invitees.
    public var isAccepted: Bool

    public init(
        id: String, title: String, start: Date, end: Date, isAllDay: Bool = false, notes: String? = nil,
        location: String? = nil, url: URL? = nil, calendarTitle: String, isAccepted: Bool = true
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.notes = notes
        self.location = location
        self.url = url
        self.calendarTitle = calendarTitle
        self.isAccepted = isAccepted
    }

    /// The video call to open when the task goes live: the event's link, or the first Meet, Zoom, Teams or Webex
    /// link in its location or notes.
    public var meetingLink: URL? {
        if let url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") { return url }
        let hosts = ["meet.google.com", "zoom.us", "teams.microsoft.com", "teams.live.com", "webex.com"]
        return NoteLinks.find(in: [location, notes].compactMap { $0 }.joined(separator: "\n")).first { url in
            hosts.contains { url.host()?.hasSuffix($0) == true }
        }
    }
}

/// Calendar → Komodo (FEATURES §5): each event in range becomes a task on the chosen list, placed by its date.
/// IDs come from the events, so a sync never duplicates, and a task deleted in Komodo stays deleted.
public enum CalendarImport {
    public static let idPrefix = "calendar:"

    public static func taskID(for event: CalendarEvent) -> String { idPrefix + event.id }

    /// The tasks to save: new events, events that moved or were renamed, and tasks whose event is gone, which only
    /// lose their link (FEATURES §5: "Deleting at the provider only unlinks the task").
    ///
    /// - Parameters:
    ///   - board: open and done tasks on the Board.
    ///   - known: every task ID Komodo has, Trash and archive included, so those never come back.
    ///   - calendars: the calendars that were read, so a task from one that wasn't isn't unlinked.
    ///   - days: the first and last day that were read.
    public static func sync(
        _ events: [CalendarEvent], board: [TaskItem], known: Set<String>, listID: String, calendars: Set<String>,
        days: ClosedRange<LocalDate>, acceptedOnly: Bool, week: WeekRange, now: Date, calendar: Calendar
    ) -> [TaskItem] {
        let wanted = events.filter { !acceptedOnly || $0.isAccepted }
        let byID = Dictionary(board.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var saved: [TaskItem] = []
        var nextRank: [Bucket: Double] = [:]

        for event in wanted {
            let id = taskID(for: event)
            let day = LocalDate(event.start, calendar: calendar)
            let minute =
                event.isAllDay
                ? nil
                : calendar.component(.hour, from: event.start) * 60 + calendar.component(.minute, from: event.start)
            let estimate = event.isAllDay ? nil : max(0, event.end.timeIntervalSince(event.start))
            if var task = byID[id] {
                guard !task.isDone else { continue }
                let before = task
                task.title = event.title
                task.scheduledDate = day
                task.scheduledMinute = minute
                task.estimate = estimate
                task.source = .calendar
                task.sourceTitle = event.calendarTitle
                task.sourceURL = event.meetingLink
                if task != before { saved.append(task) }
                continue
            }
            guard !known.contains(id) else { continue }
            var task = TaskItem(
                id: id, listID: listID, title: event.title, bucket: .backlog, rank: 0, estimate: estimate,
                notes: event.notes, scheduledDate: day, scheduledMinute: minute, source: .calendar,
                sourceTitle: event.calendarTitle, sourceURL: event.meetingLink, createdAt: now)
            let column = task.column(in: week)
            let rank =
                nextRank[column]
                ?? (board.filter { $0.column(in: week) == column && !$0.isDone }.map(\.rank).max() ?? 0) + 1
            task.rank = rank
            nextRank[column] = rank + 1
            saved.append(task)
        }

        let present = Set(wanted.map(taskID))
        for task in board
        where task.id.hasPrefix(idPrefix) && task.source == .calendar && !task.isDone && !present.contains(task.id)
            && calendars.contains(task.sourceTitle ?? "") && task.scheduledDate.map(days.contains) == true
        {
            var unlinked = task
            unlinked.source = nil
            unlinked.sourceTitle = nil
            unlinked.sourceURL = nil
            saved.append(unlinked)
        }
        return saved
    }
}
