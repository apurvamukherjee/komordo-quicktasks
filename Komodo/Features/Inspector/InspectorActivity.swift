import KomodoCore
import SwiftUI

/// SOURCE · GMAIL: who the task came from and a link back to it. Only for tasks from Gmail, a calendar or Todoist.
struct InspectorSource: View {
    var task: TaskItem
    var source: TaskSource

    @Environment(\.openURL) private var openURL

    private var name: String {
        switch source {
        case .gmail: "Gmail"
        case .calendar: "Calendar"
        case .todoist: "Todoist"
        }
    }

    private var icon: String {
        switch source {
        case .gmail: "envelope"
        case .calendar: "calendar"
        case .todoist: "checklist"
        }
    }

    var body: some View {
        HStack(spacing: Space.s3) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.ember)
                .frame(width: 34, height: 34)
                .background(Palette.ember.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("SOURCE · \(name.uppercased())")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Palette.textSecondary)
                Text(task.sourceTitle ?? name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(added)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let url = task.sourceURL {
                Button("Open ↗") { openURL(url) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.tealText)
            }
        }
        .inspectorSection(SpotlightTint.review)
    }

    private var added: String {
        let when = task.createdAt.map { " · " + $0.formatted(.dateTime.month(.abbreviated).day()) } ?? ""
        return "Added to Komodo · From \(name)\(when)"
    }
}

/// SESSIONS: how many and how long, with the latest four as bars. **View** opens Reports once they exist.
struct InspectorSessions: View {
    var task: TaskItem
    var now: Date

    private static let barCount = 4

    var body: some View {
        HStack(spacing: Space.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SESSIONS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Palette.textSecondary)
                Text(summary)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Palette.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            bars
            Button("View") {}
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.violetText)
                .disabled(true)
                .help("Sessions open in Reports, which arrive later")
        }
        .inspectorSection(Palette.violet)
    }

    private var summary: String {
        let count = task.sessions.count
        guard count > 0 else { return "No sessions yet" }
        return "\(count) · \(DurationFormat.short(task.timeTaken(at: now))) total"
    }

    /// The latest sessions, oldest to newest, scaled to the longest; the newest one glows.
    private var bars: some View {
        let lengths = task.sessions.suffix(Self.barCount).map { $0.duration(until: now) }
        let longest = max(lengths.max() ?? 0, 1)
        let heights =
            Array(repeating: 0.2, count: Self.barCount - lengths.count) + lengths.map { max(0.2, $0 / longest) }
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                let isNewest = index == Self.barCount - 1 && !lengths.isEmpty
                RoundedRectangle(cornerRadius: 2)
                    .fill(Palette.violet)
                    .frame(width: 6, height: 24 * height)
                    .opacity(isNewest ? 1 : 0.5 + Double(index) * 0.1)
                    .shadow(color: isNewest ? Palette.violet : .clear, radius: 4)
            }
        }
        .frame(height: 24, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

#Preview("Inspector source and sessions") {
    let store = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)
    VStack(spacing: Space.s3) {
        if let review = store.tasks.first(where: { $0.id == "design-review" }), let source = review.source {
            InspectorSource(task: review, source: source)
            InspectorSessions(task: review, now: store.now)
        }
        if let visa = store.tasks.first(where: { $0.id == "visa" }) {
            InspectorSessions(task: visa, now: store.now)
        }
    }
    .frame(width: 356)
    .padding(Space.s6)
    .background(Palette.panel)
}
