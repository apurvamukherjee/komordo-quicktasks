import AppKit
import KomodoCore
import OSLog
import UserNotifications

/// Focus mode's sound and notifications (DESIGN_SYSTEM §14.2, FEATURES §4.10–4.11): when a sprint ends and its
/// break starts, and when the break is over, with Resume on the notification. Permission is asked the first time
/// one is needed, until onboarding asks up front.
@MainActor final class FocusAlerts: NSObject, UNUserNotificationCenterDelegate {
    private enum ID {
        static let breakOverCategory = "breakOver"
        static let resume = "resume"
    }

    /// Resume on the break-over notification.
    var onResume: () -> Void = {}

    private var center: UNUserNotificationCenter { .current() }

    func install() {
        center.delegate = self
        let resume = UNNotificationAction(identifier: ID.resume, title: "Resume", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: ID.breakOverCategory, actions: [resume], intentIdentifiers: [])
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

    private func post(title: String, body: String, category: String?) {
        Task { await Self.deliver(title: title, body: body, category: category) }
    }

    /// Builds and adds the request off the main actor, so nothing non-Sendable crosses over.
    private nonisolated static func deliver(title: String, body: String, category: String?) async {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional:
            break
        case .notDetermined:
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        default:
            // Declined in System Settings; the panel and the sound still say it.
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let category { content.categoryIdentifier = category }
        do {
            try await center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        } catch {
            Logger(subsystem: "app.komodo.Komodo", category: "alerts").error("Notification failed: \(error)")
        }
    }

    // Komodo is often in front while Focus mode runs, so banners show then too.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == ID.resume else { return }
        await MainActor.run { onResume() }
    }
}
