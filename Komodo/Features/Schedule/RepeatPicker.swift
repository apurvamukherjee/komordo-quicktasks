import KomodoCore
import SwiftUI

/// The Repeat menu (DESIGN_SYSTEM §13.6): Doesn't repeat · Every day · Every weekday · Weekly on *day* ·
/// Monthly on the *n*th · Custom…, as a native menu with a checkmark on the current rule.
struct RepeatPicker: View {
    @Binding var rule: RepeatRule?
    var start: LocalDate
    var calendar: Calendar
    var customize: () -> Void

    private enum Choice: Hashable {
        case never
        case everyDay
        case everyWeekday
        case weekly
        case monthly
        case custom
    }

    var body: some View {
        Picker("Repeat", selection: Binding(get: { choice }, set: choose)) {
            Text("Doesn't repeat").tag(Choice.never)
            Divider()
            Text("Every day").tag(Choice.everyDay)
            Text("Every weekday").tag(Choice.everyWeekday)
            Text("Weekly on \(calendar.weekdaySymbols[start.isoWeekday(calendar: calendar) % 7])")
                .tag(Choice.weekly)
            Text(RepeatRule.monthly.summary(from: start, calendar: calendar)).tag(Choice.monthly)
            Divider()
            Text(choice == .custom ? rule.map { $0.summary(from: start, calendar: calendar) } ?? "Custom…" : "Custom…")
                .tag(Choice.custom)
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
    }

    private var choice: Choice {
        switch rule?.kind {
        case nil: .never
        case .everyDay: .everyDay
        case .everyWeekday: .everyWeekday
        // A weekly rule on another day than the start's reads as custom, so the menu never lies.
        case .weekly where rule?.weekdays.first.map({ $0 == start.isoWeekday(calendar: calendar) }) ?? true: .weekly
        case .monthly: .monthly
        case .weekly, .custom: .custom
        }
    }

    private func choose(_ choice: Choice) {
        switch choice {
        case .never: rule = nil
        case .everyDay: rule = .everyDay
        case .everyWeekday: rule = .everyWeekday
        case .weekly: rule = .weekly(on: start.isoWeekday(calendar: calendar))
        case .monthly: rule = .monthly
        case .custom: customize()
        }
    }
}

/// Custom… (DESIGN_SYSTEM §13.6): "Every [2] [weeks]", the weekday row as 24 pt circles, and Ends: Never or On
/// a date, summed up in one sentence.
struct CustomRepeatSheet: View {
    var title: String
    var start: LocalDate
    var calendar: Calendar
    var done: (RepeatRule) -> Void
    var cancel: () -> Void

    @State private var interval: Int
    @State private var unit: RepeatRule.Unit
    @State private var weekdays: Set<Int>
    @State private var endsOn: LocalDate?

    init(
        title: String, start: LocalDate, rule: RepeatRule?, calendar: Calendar, done: @escaping (RepeatRule) -> Void,
        cancel: @escaping () -> Void
    ) {
        self.title = title
        self.start = start
        self.calendar = calendar
        self.done = done
        self.cancel = cancel
        let rule = rule ?? RepeatRule(unit: .week)
        _interval = State(initialValue: rule.interval)
        _unit = State(initialValue: rule.unit)
        _weekdays = State(initialValue: rule.weekdays.isEmpty ? [start.isoWeekday(calendar: calendar)] : rule.weekdays)
        _endsOn = State(initialValue: rule.endsOn)
    }

    private var rule: RepeatRule {
        RepeatRule(interval: interval, unit: unit, weekdays: unit == .week ? weekdays : [], endsOn: endsOn)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            HStack(spacing: Space.s3) {
                Image(systemName: "repeat")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.violetText)
                    .frame(width: 32, height: 32)
                    .background(Palette.violet.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.violet.opacity(0.32), lineWidth: 1))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Custom repeat").font(.system(size: 15, weight: .bold)).foregroundStyle(Palette.textPrimary)
                    Text(title).font(.system(size: 12)).foregroundStyle(Palette.textMuted).lineLimit(1)
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text("Every").frame(width: 44, alignment: .leading)
                    Stepper(value: $interval, in: 1...99) {
                        Text("\(interval)").monospacedDigit().frame(minWidth: 22)
                    }
                    Picker("Unit", selection: $unit) {
                        ForEach(RepeatRule.Unit.allCases, id: \.self) { unit in
                            Text(interval == 1 ? unit.rawValue : "\(unit.rawValue)s").tag(unit)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                if unit == .week {
                    HStack(spacing: 10) {
                        Text("On").frame(width: 44, alignment: .leading)
                        WeekdayRow(selection: $weekdays, calendar: calendar)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .spotlight(SpotlightTint.backlog, radius: Radius.tile, lifts: false) { TileSurface(radius: Radius.tile) }
            HStack(alignment: .top, spacing: 10) {
                Text("Ends").frame(width: 44, alignment: .leading)
                Picker("Ends", selection: Binding(get: { endsOn != nil }, set: setEnds)) {
                    Text("Never").tag(false)
                    Text("On date").tag(true)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
                DatePicker(
                    "End date",
                    selection: Binding(
                        get: { (endsOn ?? defaultEnd).startOfDay(in: calendar) },
                        set: { endsOn = LocalDate($0, calendar: calendar) }),
                    in: start.startOfDay(in: calendar)...,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.field)
                .fixedSize()
                .disabled(endsOn == nil)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .spotlight(SpotlightTint.week, radius: Radius.tile, lifts: false) { TileSurface(radius: Radius.tile) }
            Label(rule.sentence(from: start, calendar: calendar), systemImage: "info.circle")
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, Space.s3)
                .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
                .background(Palette.violet.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.violet.opacity(0.2), lineWidth: 1))
            HStack(spacing: 10) {
                Spacer()
                Button("Cancel", action: cancel)
                    .buttonStyle(.komodo(.secondary))
                    .keyboardShortcut(.cancelAction)
                Button("Done") { done(rule) }
                    .buttonStyle(.komodo(.primary))
                    .keyboardShortcut(.defaultAction)
                    .disabled(unit == .week && weekdays.isEmpty)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Palette.textBody)
        .padding(Space.s5)
        .frame(width: 400)
        .background(Palette.raised)
    }

    /// Four weeks after the start, a first guess the date field changes from.
    private var defaultEnd: LocalDate { start.adding(days: 28, calendar: calendar) }

    private func setEnds(_ ends: Bool) { endsOn = ends ? endsOn ?? defaultEnd : nil }
}

/// M T W T F S S as 24 pt circles; picked days fill lime.
private struct WeekdayRow: View {
    @Binding var selection: Set<Int>
    var calendar: Calendar

    var body: some View {
        HStack(spacing: Space.s2) {
            ForEach(1...7, id: \.self) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(calendar.veryShortWeekdaySymbols[day % 7])
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(isOn ? Palette.onAccent : Palette.textSecondary)
                        .frame(width: 24, height: 24)
                        .background(isOn ? Palette.lime : Color.white.opacity(0.06), in: Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(isOn ? 0 : 0.1), lineWidth: 1))
                        .shadow(color: isOn ? Palette.lime.opacity(0.45) : .clear, radius: 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(calendar.weekdaySymbols[day % 7])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

#Preview("Custom repeat") {
    CustomRepeatSheet(
        title: "Design review with Apurva", start: LocalDate(year: 2026, month: 10, day: 1),
        rule: RepeatRule(interval: 2, unit: .week, weekdays: [2, 4]), calendar: .current, done: { _ in },
        cancel: {})
}
