import EventKit
import KomodoCore
import OSLog
import SwiftUI

/// Calendar import through macOS Calendar (FEATURES §5): whatever accounts the Mac already has, iCloud, Google or
/// Exchange, with no sign-in of Komodo's own. Syncs at launch, when Calendar's data changes, when the day turns
/// over, and on Sync now; there's nothing to poll.
@MainActor @Observable final class CalendarSync {
    enum Access: Equatable {
        case notDetermined
        case granted
        /// Denied, restricted, or write-only: Komodo can't read events.
        case denied
    }

    /// One of the Mac's calendars, for the Integrations page.
    struct Choice: Identifiable, Equatable {
        var id: String
        var title: String
        /// The account it belongs to, such as "iCloud" or "apurva@gmail.com".
        var account: String
        var color: Color
    }

    private(set) var access: Access
    private(set) var calendars: [Choice] = []
    private(set) var isSyncing = false

    @ObservationIgnored private let eventStore = EKEventStore()
    @ObservationIgnored private weak var store: BoardStore?
    private static let log = Logger(subsystem: "app.komodo.Komodo", category: "calendar")

    init() {
        access = Self.currentAccess
        #if DEBUG
            if Self.usesSamples { access = .granted }
        #endif
    }

    private static var currentAccess: Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    func attach(_ store: BoardStore) {
        self.store = store
        store.calendarSync = self
        let center = NotificationCenter.default
        for name in [Notification.Name.EKEventStoreChanged, .NSCalendarDayChanged] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.sync() }
            }
        }
        refreshCalendars()
        sync()
    }

    /// Connect: macOS asks once for access to Calendar; on yes, every calendar starts selected.
    func connect() async {
        do {
            if access != .granted {
                let granted = try await eventStore.requestFullAccessToEvents()
                access = granted ? .granted : .denied
            }
        } catch {
            Self.log.error("Calendar access failed: \(error)")
            access = .denied
        }
        guard access == .granted, let store else { return }
        refreshCalendars()
        if store.settings.calendarIDs.isEmpty { store.settings.calendarIDs = calendars.map(\.id) }
        store.settings.importsCalendars = true
        sync()
    }

    /// Stops importing. Tasks already imported stay, as ordinary tasks with their link.
    func disconnect() {
        store?.settings.importsCalendars = false
    }

    func refreshCalendars() {
        guard access == .granted else { return }
        #if DEBUG
            if Self.usesSamples {
                calendars = Self.sampleCalendars
                return
            }
        #endif
        calendars = eventStore.calendars(for: .event)
            .map {
                Choice(
                    id: $0.calendarIdentifier, title: $0.title, account: $0.source.title,
                    color: Color(cgColor: $0.cgColor))
            }
            .sorted { ($0.account, $0.title) < ($1.account, $1.title) }
    }

    /// Reads the chosen calendars from the start of today through the range and hands the events to the store.
    func sync() {
        guard let store, store.settings.importsCalendars, access == .granted, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        let calendar = store.calendar
        let today = store.today
        let last = today.adding(days: store.settings.calendarWeeks * 7 - 1, calendar: calendar)
        let chosen = Set(store.settings.calendarIDs)
        let events: [CalendarEvent]
        let titles: Set<String>
        #if DEBUG
            if Self.usesSamples {
                titles = Set(Self.sampleCalendars.filter { chosen.contains($0.id) }.map(\.title))
                events = Self.sampleEvents(from: today.startOfDay(in: calendar), calendar: calendar)
                    .filter { titles.contains($0.calendarTitle) }
                store.importCalendarEvents(events, calendars: titles, days: today...last)
                store.settings.lastCalendarSync = store.now
                return
            }
        #endif
        let sources = eventStore.calendars(for: .event).filter { chosen.contains($0.calendarIdentifier) }
        titles = Set(sources.map(\.title))
        if sources.isEmpty {
            events = []
        } else {
            let start = today.startOfDay(in: calendar)
            let end = last.adding(days: 1, calendar: calendar).startOfDay(in: calendar)
            let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: sources)
            events = eventStore.events(matching: predicate).compactMap(Self.event)
        }
        store.importCalendarEvents(events, calendars: titles, days: today...last)
        store.settings.lastCalendarSync = store.now
    }

    /// Cancelled events are skipped. An occurrence is told apart from the rest of its series by its start.
    private static func event(_ event: EKEvent) -> CalendarEvent? {
        guard event.status != .canceled, let start = event.startDate, let end = event.endDate else { return nil }
        let series = event.calendarItemExternalIdentifier ?? event.calendarItemIdentifier
        let me = event.attendees?.first(where: \.isCurrentUser)
        return CalendarEvent(
            id: series + "@" + start.ISO8601Format(), title: event.title ?? "Untitled event", start: start, end: end,
            isAllDay: event.isAllDay, notes: event.notes, location: event.location, url: event.url,
            calendarTitle: event.calendar?.title ?? "Calendar",
            // Without invitees, or as the organizer, there's nothing to accept.
            isAccepted: me.map { $0.participantStatus == .accepted } ?? true)
    }
}

#if DEBUG
    extension CalendarSync {
        /// `-sampleCalendar YES` stands in for macOS Calendar, so the page and imported tasks can be captured
        /// without the system asking for access.
        static var usesSamples: Bool { UserDefaults.standard.bool(forKey: "sampleCalendar") }

        static let sampleCalendars = [
            Choice(id: "sample-work", title: "Work", account: "apurva@gmail.com", color: Palette.blue),
            Choice(id: "sample-home", title: "Home", account: "iCloud", color: Palette.green),
            Choice(id: "sample-holidays", title: "Holidays", account: "Other", color: Palette.violet),
        ]

        static func sampleEvents(from today: Date, calendar: Calendar) -> [CalendarEvent] {
            func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
                calendar.date(byAdding: DateComponents(day: day, hour: hour, minute: minute), to: today) ?? today
            }
            return [
                CalendarEvent(
                    id: "standup", title: "Team standup", start: at(0, 16, 30), end: at(0, 16, 45),
                    url: URL(string: "https://meet.google.com/kmd-stnd-upp"), calendarTitle: "Work"),
                CalendarEvent(
                    id: "review", title: "Design review with Apurva", start: at(1, 15), end: at(1, 16),
                    location: "https://zoom.us/j/4815162342", calendarTitle: "Work"),
                CalendarEvent(
                    id: "dentist", title: "Dentist", start: at(2, 9, 30), end: at(2, 10, 15), calendarTitle: "Home"),
                CalendarEvent(
                    id: "planning", title: "Quarterly planning", start: at(8, 10), end: at(8, 12),
                    calendarTitle: "Work", isAccepted: false),
            ]
        }
    }
#endif
