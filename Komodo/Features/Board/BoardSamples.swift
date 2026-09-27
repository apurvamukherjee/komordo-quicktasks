import KomodoCore
import SwiftUI

/// In-memory sample data shaped like the Main artboard, placed relative to the real date so the columns, the
/// week strip and the projections all read naturally whenever the app runs.
enum BoardSamples {
    static let lists = [
        TaskList(id: "work", name: "Work", color: "lime"),
        TaskList(id: "personal", name: "Personal", color: "teal"),
        TaskList(id: "side", name: "Side project", color: "blue", letter: "S"),
        TaskList(id: "launch", name: "Launch", color: "pink"),
        TaskList(id: "growth", name: "Growth", color: "amber"),
    ]

    /// The Main artboard's moment: Saturday, Sep 26 2026 at 2:14 PM, 9:26 left on the live task.
    static var artboardMoment: Date {
        DateComponents(calendar: .current, year: 2026, month: 9, day: 26, hour: 14, minute: 14).date ?? .now
    }

    /// Sample data around `anchor`. With an anchor, the Board's clock starts there and keeps running, so previews
    /// and screenshots show the artboard's day at any hour; without one, it's placed around the real time.
    @MainActor
    static func store(anchoredAt anchor: Date? = nil, calendar: Calendar = .current) -> BoardStore {
        let launch = Date()
        let start = anchor ?? launch
        return BoardStore(
            lists: lists, tasks: tasks(now: start, calendar: calendar), selectedListID: "work", calendar: calendar,
            clock: { start.addingTimeInterval(Date().timeIntervalSince(launch)) })
    }

    static func tasks(now: Date, calendar: Calendar) -> [TaskItem] {
        let today = LocalDate(now, calendar: calendar)
        let week = WeekRange(containing: today, calendar: calendar)
        let laterThisWeek = today < week.end ? week.end : nil
        let yesterday = now.addingTimeInterval(-86_400)
        func minutesAgo(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        func subtasks(_ done: Int, of total: Int) -> [Subtask] {
            (0..<total).map { Subtask(id: UUID().uuidString, title: "Step \($0 + 1)", isDone: $0 < done) }
        }

        var tasks = [
            // Backlog
            TaskItem(
                id: "roadmap", listID: "work", title: "Q4 engineering roadmap", bucket: .backlog, rank: 1,
                estimate: 10_800, notes: "Themes, bets, and what we're not doing.", subtasks: subtasks(0, of: 5)),
            TaskItem(
                id: "mcp", listID: "work", title: "Local MCP server: tool surface spec", bucket: .backlog, rank: 2,
                estimate: 5_400, subtasks: subtasks(2, of: 6),
                sessions: [WorkSession(start: yesterday, end: yesterday.addingTimeInterval(1_200))]),
            TaskItem(
                id: "weekly", listID: "work", title: "Weekly review", bucket: .backlog, rank: 3, estimate: 2_700,
                repeatSummary: "Every Friday"),
            TaskItem(
                id: "hire", listID: "work", title: "Hire a product designer", bucket: .backlog, rank: 4,
                estimate: 3_600),

            // This week
            TaskItem(
                id: "wireframes", listID: "work", title: "Wireframes: floating timer pill", bucket: .week, rank: 1,
                estimate: 7_200, scheduledDate: laterThisWeek, scheduledMinute: laterThisWeek == nil ? nil : 600,
                subtasks: subtasks(1, of: 3),
                sessions: [WorkSession(start: yesterday, end: yesterday.addingTimeInterval(1_080))]),
            TaskItem(
                id: "rtf", listID: "work", title: "Rich-text notes: RTF export", bucket: .week, rank: 2,
                estimate: 4_500,
                notes: "Spec: https://developer.apple.com/documentation/appkit/nstextview\n"
                    + "Sample: https://github.com/komodo-app/rtf-fixtures"),
            TaskItem(
                id: "visa", listID: "work", title: "Submit visa form", bucket: .week, rank: 3, estimate: 1_800,
                dueDate: today.adding(days: 14, calendar: calendar), source: .gmail),

            // Today: the live task, the queue, a meeting, and two done
            TaskItem(
                id: "design-review", listID: "work", title: "Design review prep with Apurva", bucket: .today,
                rank: 0, estimate: 3_600,
                notes: "Notes stay editable while the task is live.\nFigma: https://figma.com/file/komodo-inspector\n"
                    + "Deck: https://pitch.com/komodo-review",
                subtasks: subtasks(2, of: 3), source: .gmail,
                sessions: [WorkSession(start: minutesAgo(50.5))]),
            TaskItem(
                id: "detector", listID: "work", title: "Wire NSDataDetector date parsing", bucket: .today, rank: 1,
                estimate: 5_400, subtasks: subtasks(3, of: 4),
                sessions: [WorkSession(start: minutesAgo(140), end: minutesAgo(110))]),
            TaskItem(
                id: "accounts", listID: "work", title: "Review accounts", bucket: .today, rank: 2, estimate: 9_000,
                notes: "Q3 invoices and the new vendor."),
            TaskItem(
                id: "one-on-one", listID: "work", title: "Prep 1:1 with Apurva", bucket: .today, rank: 3,
                estimate: 1_800, notes: "Growth plan, feedback.", subtasks: subtasks(0, of: 3)),
            TaskItem(
                id: "casa", listID: "work", title: "Sync with core team on CASA review", bucket: .today, rank: 4,
                estimate: 2_700, scheduledDate: today, scheduledMinute: 15 * 60, source: .calendar),
            TaskItem(
                id: "intro", listID: "work", title: "Reply to Apurva's intro email", bucket: .today, rank: -2,
                estimate: 1_800, completedAt: minutesAgo(170),
                sessions: [WorkSession(start: minutesAgo(188), end: minutesAgo(170))]),
            TaskItem(
                id: "copy", listID: "work", title: "Fix onboarding copy", bucket: .today, rank: -1, estimate: 2_700,
                completedAt: minutesAgo(150), sessions: [WorkSession(start: minutesAgo(182), end: minutesAgo(150))]),
        ]

        // Other lists, so the sidebar counts and All lists have something to show.
        let others: [(String, [String])] = [
            ("personal", ["Call the bank", "Book dentist", "Plan weekend hike", "Renew passport"]),
            (
                "side",
                [
                    "Landing page copy", "App icon exploration", "Beta invite list", "Crash reporter", "Sparkle feed",
                    "Pricing page", "Changelog",
                ]
            ),
            ("launch", ["Press kit", "Launch tweet thread", "Product Hunt assets"]),
            ("growth", ["Onboarding funnel review", "Referral experiment"]),
        ]
        for (listID, titles) in others {
            for (index, title) in titles.enumerated() {
                tasks.append(
                    TaskItem(
                        id: "\(listID)-\(index)", listID: listID, title: title,
                        bucket: index == 0 ? .week : .backlog, rank: Double(index), estimate: 1_800))
            }
        }
        // Finished work on earlier days: the sidebar's history bars and a 4-day streak.
        for (daysAgo, minutes) in [(1, 150.0), (2, 95.0), (3, 180.0), (5, 60.0), (6, 120.0)] {
            let end = now.addingTimeInterval(-Double(daysAgo) * 86_400)
            tasks.append(
                TaskItem(
                    id: "history-\(daysAgo)", listID: "work", title: "Earlier work", bucket: .today, rank: 0,
                    estimate: minutes * 60, completedAt: end,
                    sessions: [WorkSession(start: end.addingTimeInterval(-minutes * 60), end: end)]))
        }
        return tasks
    }
}
