import AppKit
import KomodoCore
import OSLog
import UserNotifications

/// Komodo's notifications (DESIGN_SYSTEM §14.2, FEATURES §4.10–4.12): a sprint's end, a break that's over with
/// Resume, Time's Up with +5 min and Done while the panel is hidden, and each scheduled task's reminder with Start
/// now and Snooze 5 min. Reminders are scheduled with the system, so they fire while Komodo is closed. Permission
/// is asked the first time one is needed, until onboarding asks up front.
@MainActor final class FocusAlerts: NSObject, UNUserNotificationCenterDelegate {
    private enum ID {
        static let breakOverCategory = "breakOver"
        static let resume = "resume"
        static let timesUpCategory = "timesUp"
        static let extend = "extend"
        static let done = "done"
        static let reminderCategory = "reminder"
        static let startNow = "startNow"
        static let snooze = "snooze"
        static let reminderPrefix = "reminder."
        static let taskKey = "taskID"
    }

    /// Resume on the break-over notification.
    var onResume: () -> Void = {}
    /// +5 min and Done on Time's Up.
    var onExtend: () -> Void = {}
    var onDone: () -> Void = {}
    /// Start now on a reminder, with the task's id.
    var onStartNow: (String) -> Void = { _ in }
    /// A click on a reminder's body opens its task.
    var onOpen: (String) -> Void = { _ in }

    private var center: UNUserNotificationCenter { .current() }

    func install() {
        center.delegate = self
        func action(_ id: String, _ title: String) -> UNNotificationAction {
            UNNotificationAction(identifier: id, title: title, options: [.foreground])
        }
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: ID.breakOverCategory, actions: [action(ID.resume, "Resume")], intentIdentifiers: []),
            UNNotificationCategory(
                identifier: ID.timesUpCategory, actions: [action(ID.extend, "+5 min"), action(ID.done, "Done")],
                intentIdentifiers: []),
            UNNotificationCategory(
                identifier: ID.reminderCategory,
                actions: [
                    action(ID.startNow, "Start now"),
                    UNNotificationAction(identifier: ID.snooze, title: "Snooze 5 min", options: []),
                ],
                intentIdentifiers: []),
        ])
    }

    func sprintEnded(sprint: Int, of count: Int, breakLength: TimeInterval, task: String) {
        post(
            title: "Sprint \(sprint) of \(count) done",
            body: "Take \(DurationFormat.short(breakLength)). \(task) is paused.", category: nil)
    }

    func breakOver(task: String) {
        post(title: "Break's over", body: "Back to \(task)?", category: ID.breakOverCategory)
    }

    func timesUp(task: String, estimate: TimeInterval) {
        post(
            title: "Time's up", body: "\(task) · \(DurationFormat.short(estimate)) estimate",
            category: ID.timesUpCategory)
    }

    /// Replaces every pending reminder with these.
    func syncReminders(_ reminders: [Reminder], calendar: Calendar) {
        Task { await Self.replaceReminders(reminders, calendar: calendar) }
    }

    private func post(title: String, body: String, category: String?) {
        Task { await Self.deliver(title: title, body: body, category: category) }
    }

    // MARK: Delivery

    // Requests are built off the main actor, so nothing non-Sendable crosses over.

    private nonisolated static func deliver(title: String, body: String, category: String?) async {
        let center = UNUserNotificationCenter.current()
        guard await isAllowed(center) else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let category { content.categoryIdentifier = category }
        await add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil), to: center)
    }

    private nonisolated static func replaceReminders(_ reminders: [Reminder], calendar: Calendar) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { $0.hasPrefix(ID.reminderPrefix) })
        guard !reminders.isEmpty, await isAllowed(center) else { return }
        for reminder in reminders {
            let content = reminderContent(taskID: reminder.taskID, title: reminder.title)
            let moment = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: moment, repeats: false)
            await add(
                UNNotificationRequest(
                    identifier: ID.reminderPrefix + reminder.taskID, content: content, trigger: trigger),
                to: center)
        }
    }

    private nonisolated static func reminderContent(taskID: String, title: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "Starts now"
        content.categoryIdentifier = ID.reminderCategory
        content.userInfo = [ID.taskKey: taskID]
        content.sound = .default
        return content
    }

    private nonisolated static func isAllowed(_ center: UNUserNotificationCenter) async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                Logger(subsystem: "app.komodo.Komodo", category: "alerts").error("Permission failed: \(error)")
                return false
            }
        default:
            // Declined in System Settings; the panel and the sound still say it.
            return false
        }
    }

    private nonisolated static func add(_ request: UNNotificationRequest, to center: UNUserNotificationCenter) async {
        do {
            try await center.add(request)
        } catch {
            Logger(subsystem: "app.komodo.Komodo", category: "alerts").error("Notification failed: \(error)")
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    // Komodo is often in front while Focus mode runs, so banners show then too.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        let content = response.notification.request.content
        let taskID = content.userInfo[ID.taskKey] as? String
        switch response.actionIdentifier {
        case ID.resume:
            await MainActor.run { onResume() }
        case ID.extend:
            await MainActor.run { onExtend() }
        case ID.done:
            await MainActor.run { onDone() }
        case ID.startNow:
            guard let taskID else { return }
            await MainActor.run { onStartNow(taskID) }
        case UNNotificationDefaultActionIdentifier:
            guard let taskID else { return }
            await MainActor.run { onOpen(taskID) }
        case ID.snooze:
            guard let taskID else { return }
            let again = Self.reminderContent(taskID: taskID, title: content.title)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5 * 60, repeats: false)
            await Self.add(
                UNNotificationRequest(identifier: ID.reminderPrefix + taskID, content: again, trigger: trigger),
                to: center)
        default:
            break
        }
    }
}
