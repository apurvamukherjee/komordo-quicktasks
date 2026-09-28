import KomodoCore
import SwiftUI

/// Step 2 (DESIGN_SYSTEM §13.6): the day with a way back, an optional time, the repeat rule, the reminder and
/// Save. Changing an existing repeat asks whether to replace this week's copies, or delete them when it stops.
struct ScheduleDetailsStep: View {
    var store: BoardStore
    @Binding var draft: BoardStore.Schedule
    var original: BoardStore.Schedule
    /// Only a task that has a day or a repeat has anything to remove.
    var canRemove: Bool
    var back: () -> Void
    var customize: () -> Void
    var remove: () -> Void
    var save: () -> Void

    private var calendar: Calendar { store.calendar }
    private var repeatChanged: Bool { original.rule != nil && draft.rule != original.rule }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            header
            VStack(alignment: .leading, spacing: 10) {
                InspectorRow("Time") { time }
                InspectorRow("Repeat") {
                    RepeatPicker(
                        rule: $draft.rule, start: draft.date, calendar: calendar, customize: customize)
                }
            }
            .padding(Space.s3)
            .spotlight(SpotlightTint.week, radius: Radius.tile, lifts: false) { TileSurface(radius: Radius.tile) }
            if let minute = draft.minute, !repeatChanged {
                Text(explanation(minute: minute))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if repeatChanged { existingTasksChoice }
            if draft.minute != nil {
                HStack {
                    Label("Reminder at start time", systemImage: "bell")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Toggle("Reminder at start time", isOn: $draft.remindsAtStart)
                        .labelsHidden()
                        .komodoSwitch()
                }
                .padding(.horizontal, Space.s3)
                .frame(height: 40)
                .spotlight(SpotlightTint.success, radius: Radius.tile, lifts: false) {
                    TileSurface(radius: Radius.tile)
                }
            }
            HStack {
                Button("Remove schedule", role: .destructive, action: remove)
                    .buttonStyle(.komodo(.dangerOutline, size: .small))
                    .disabled(!canRemove)
                Spacer()
                Button("Save", action: save)
                    .buttonStyle(.komodo(.primary, size: .small))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button("Back to the calendar", systemImage: "arrow.left", action: back)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
            Text(
                draft.date.startOfDay(in: calendar).formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            )
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Palette.textPrimary)
            Spacer()
            if let previous = original.rule, repeatChanged {
                Chip("Was: \(previous.summary(from: original.date, calendar: calendar))", tint: .violet, size: .compact)
            } else if let distance = distanceLabel {
                Chip(distance, tint: .blue, size: .compact)
            }
        }
    }

    @ViewBuilder private var time: some View {
        if let minute = draft.minute {
            TimeField(
                date: Binding(
                    get: { draft.date.startOfDay(in: calendar).addingTimeInterval(TimeInterval(minute * 60)) },
                    set: {
                        let parts = calendar.dateComponents([.hour, .minute], from: $0)
                        draft.minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                    }),
                calendar: calendar)
            Button("Remove time", systemImage: "xmark") { draft.minute = nil }
                .buttonStyle(.icon(.compact))
        } else {
            Button("Add", systemImage: "plus") {
                // The next quarter hour, a sensible first guess that the stepper adjusts from.
                let parts = calendar.dateComponents([.hour, .minute], from: store.now)
                let minute = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
                draft.minute = min(23 * 60 + 45, (minute + 15) / 15 * 15)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .heavy))
            .textCase(.uppercase)
            .foregroundStyle(Palette.limeText)
        }
        Spacer(minLength: 0)
    }

    /// Replace existing tasks, or Delete existing tasks once the task stops repeating (FEATURES §4.7).
    private var existingTasksChoice: some View {
        let ending = draft.rule == nil
        return Toggle(isOn: $draft.clearsExisting) {
            VStack(alignment: .leading, spacing: 3) {
                Text(ending ? "Delete existing tasks" : "Replace existing tasks")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text(
                    ending
                        ? "Deletes this week’s unfinished copies and ends the repeat."
                        : "Deletes this week’s unfinished copies and recreates them from the new rule."
                )
                .font(.system(size: 12))
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.checkbox)
        .padding(Space.s3)
        .spotlight(SpotlightTint.review, radius: Radius.tile, lifts: false) {
            ZStack {
                TileSurface(radius: Radius.tile)
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .strokeBorder(Palette.amber.opacity(0.35), lineWidth: 1)
            }
        }
    }

    /// "In 5 days", "Tomorrow" or "Today", as on the canvas's step 2 badge.
    private var distanceLabel: String? {
        let from = store.today.startOfDay(in: calendar)
        let days = calendar.dateComponents([.day], from: from, to: draft.date.startOfDay(in: calendar)).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case 2...: return "In \(days) days"
        default: return nil
        }
    }

    /// "On Oct 1 it sits in Scheduled today, reminds you, and joins the Focus queue at 2:30 PM."
    private func explanation(minute: Int) -> String {
        let day = draft.date.startOfDay(in: calendar)
        let time = day.addingTimeInterval(TimeInterval(minute * 60)).formatted(date: .omitted, time: .shortened)
        let joins = draft.remindsAtStart ? ", reminds you, and joins" : " and joins"
        return "On \(day.formatted(.dateTime.month(.abbreviated).day())) it sits in Scheduled today\(joins)"
            + " the Focus queue at \(time)."
    }
}
