import KomodoCore
import SwiftUI

/// `.fp-q`: a compact queue row for the 340 pt panel. Its place in line, the title, a line of estimate, time
/// tracked, subtasks and notes, and the list badge. Hovering slides in Done and the bolt that makes it live.
struct FocusQueueRow: View {
    var model: TaskCardModel
    var position: Int
    var onDone: () -> Void
    var onMakeLive: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 11) {
            Text("\(position)")
                .font(.system(size: 12, weight: .heavy).monospacedDigit())
                .foregroundStyle(Palette.textBody)
                .frame(width: 26, height: 26)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(model.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                meta
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ListBadge(letter: model.listLetter, color: model.listColor, side: 20)
        }
        .padding(.vertical, Space.s2)
        .padding(.horizontal, Space.s3)
        .overlay(alignment: .trailing) {
            if isHovered {
                CardActionRow(actions: [
                    CardAction(label: "Mark done", symbol: "checkmark", perform: onDone),
                    CardAction(label: "Make live now", symbol: "bolt.fill", isGo: true, perform: onMakeLive),
                ])
                .padding(.trailing, 10)
                .transition(.opacity.combined(with: .offset(x: 8)))
            }
        }
        .spotlight(SpotlightTint.today, radius: Radius.tile) { CardSurface(radius: Radius.tile) }
        .onHover { hovering in withAnimation(Motion.base) { isHovered = hovering } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(position). \(model.title)")
        .accessibilityAction(named: "Make live now", onMakeLive)
        .accessibilityAction(named: "Mark done", onDone)
    }

    private var meta: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock").font(.system(size: 10))
            Text(model.estimate.map(DurationFormat.short) ?? "No estimate")
            separator
            Text(model.timeTaken > 0 ? "\(model.timeTakenLabel) tracked" : "00:00")
                .foregroundStyle(model.timeTaken > 0 ? Palette.limeText : Palette.textMuted)
            if let subtasks = model.subtasks {
                separator
                Label("\(subtasks.done)/\(subtasks.total)", systemImage: "checklist")
            }
            if model.hasNotes {
                separator
                Label("Notes", systemImage: "note.text")
            }
        }
        .labelStyle(TightLabelStyle())
        .font(.system(size: 11.5).monospacedDigit())
        .foregroundStyle(Palette.textSecondary)
        .lineLimit(1)
    }

    private var separator: some View { Text("·").foregroundStyle(Palette.textDisabled) }
}

/// A task with a time today: the time in a small blue block, the title, and what it is.
struct FocusScheduledRow: View {
    var time: String
    var period: String
    var title: String
    var detail: String
    var fromCalendar: Bool

    var body: some View {
        HStack(spacing: Space.s3) {
            VStack(spacing: 0) {
                Text(time)
                    .font(.system(size: 13.5, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Palette.blueText)
                Text(period)
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(0.57)
                    .foregroundStyle(Palette.textMuted)
            }
            .padding(.vertical, 4)
            .frame(width: 44)
            .background(Palette.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Palette.blue.opacity(0.22), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: fromCalendar ? "video" : "calendar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.blueText)
                .frame(width: 28, height: 28)
                .background(Palette.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .padding(.vertical, Space.s2)
        .padding(.horizontal, Space.s3)
        .spotlight(SpotlightTint.week, radius: Radius.tile) { CardSurface(radius: Radius.tile) }
        .accessibilityElement(children: .combine)
    }
}

/// `.fp-add`: `+ ADD TASK` with its ⌘⌥T shortcut, a dashed lime outline that fills faintly on hover.
struct FocusAddTaskButton: View {
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Space.s3, style: .continuous)
        Button(action: action) {
            HStack(spacing: Space.s2) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.lime)
                Text("ADD TASK").tracking(0.7)
                Spacer()
                KeyCap("⌘⌥T")
            }
            .font(.system(size: 11.5, weight: .bold))
            .foregroundStyle(isHovered ? Palette.textPrimary : Palette.textSecondary)
            .padding(.horizontal, Space.s3)
            .frame(height: 38)
            .background(Palette.lime.opacity(isHovered ? 0.05 : 0), in: shape)
            .overlay(
                shape.strokeBorder(
                    Palette.lime.opacity(isHovered ? 0.5 : 0.28), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            )
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .keyboardShortcut("t", modifiers: [.command, .option])
        .animation(Motion.fast, value: isHovered)
        .onHover { isHovered = $0 }
    }
}

#Preview("Focus panel rows") {
    VStack(spacing: 7) {
        FocusQueueRow(model: TaskCardSamples.dataDetector, position: 2, onDone: {}, onMakeLive: {})
        FocusQueueRow(model: TaskCardSamples.reviewAccounts, position: 3, onDone: {}, onMakeLive: {})
        FocusAddTaskButton {}
        FocusScheduledRow(
            time: "3:00", period: "PM", title: "Sync with core team", detail: "45min · Reminder on",
            fromCalendar: true)
    }
    .frame(width: 312)
    .padding(Space.s6)
    .background(Palette.bg)
}
