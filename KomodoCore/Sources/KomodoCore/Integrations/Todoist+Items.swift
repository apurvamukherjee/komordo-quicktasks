import Foundation

extension Todoist {
    /// `2026-10-01T09:30:00.000000Z`. The fraction is dropped first, since the formatter only reads milliseconds.
    static func instant(_ text: String) -> Date? {
        let whole = text.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return ISO8601DateFormatter().date(from: whole)
    }

    public static func taskURL(_ id: String) -> URL? { URL(string: "https://app.todoist.com/app/task/\(id)") }
}

extension Todoist.Due {
    /// The day, and the minute after midnight when there's a time. A floating time is read as written; a fixed
    /// one (ending in `Z`) is moved into the Mac's zone.
    public func schedule(in calendar: Calendar) -> (day: LocalDate, minute: Int?)? {
        if date.hasSuffix("Z") {
            guard let instant = Todoist.instant(date) else { return nil }
            let parts = calendar.dateComponents([.hour, .minute], from: instant)
            return (LocalDate(instant, calendar: calendar), (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
        }
        guard let day = LocalDate(iso: String(date.prefix(10))) else { return nil }
        let time = date.dropFirst(11).split(separator: ":").prefix(2).compactMap { Int($0) }
        return (day, time.count == 2 ? time[0] * 60 + time[1] : nil)
    }
}

extension ExternalItem {
    /// A Todoist task: its due date is when it's planned, its deadline is Komodo's due date, and a duration in
    /// minutes is the estimate. Todoist has no start date, so FEATURES §5's date mapping has nothing to choose.
    public init(_ item: Todoist.Item, userID: String?, calendar: Calendar) {
        let schedule = item.due?.schedule(in: calendar)
        self.init(
            id: item.id, title: item.content, notes: item.description.isEmpty ? nil : item.description,
            date: schedule?.day, minute: schedule?.minute,
            dueDate: item.deadline.flatMap { LocalDate(iso: String($0.date.prefix(10))) },
            estimate: item.duration.flatMap { $0.unit == "minute" ? TimeInterval($0.amount * 60) : nil },
            isDone: item.checked, isDeleted: item.isDeleted,
            isMine: item.responsibleUID == nil || item.responsibleUID == userID,
            updatedAt: item.updatedAt.flatMap(Todoist.instant), url: Todoist.taskURL(item.id))
    }
}
