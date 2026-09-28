import SwiftUI

/// The gear's popover in the Focus Panel (DESIGN_SYSTEM §13.8, FocusStates ⑧): Pomodoros with sprint and break
/// lengths, which edge the panel docks to, and sounds. Every change applies live.
struct QuickSettingsView: View {
    @Bindable var store: BoardStore

    private static let sprintRange = 5...90
    private static let breakRange = 1...30

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Quick Settings").font(.system(size: 13.5, weight: .bold)).foregroundStyle(Palette.textPrimary)
                Spacer()
                Text("Focus mode").font(.system(size: 11)).foregroundStyle(Palette.textMuted)
            }
            .padding(.horizontal, 2)
            .padding(.top, 6)
            .padding(.bottom, Space.s2)
            Divider().overlay(Palette.border)
            row(
                symbol: "timer", tint: Palette.pink, glyph: Palette.pinkText, title: "Pomodoros",
                detail: store.isPomodoroOn
                    ? "\(minutes(store.sprintLength)) min sprints, \(minutes(store.breakLength)) min breaks"
                    : "Off · EST countdown"
            ) {
                Toggle("Pomodoros", isOn: $store.isPomodoroOn).labelsHidden().komodoSwitch()
            }
            VStack(spacing: 10) {
                HStack(spacing: Space.s2) {
                    lengthField(
                        "WORK SPRINT", length: $store.sprintLength, range: Self.sprintRange, step: 5,
                        accessibility: "Work sprint length in minutes")
                    lengthField(
                        "BREAK", length: $store.breakLength, range: Self.breakRange, step: 1,
                        accessibility: "Break length in minutes")
                }
                // The live card's big number: the task's estimate with the sprint as a chip, or the sprint in pink.
                HStack {
                    Text("SPRINT DISPLAY")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Palette.textSecondary)
                    Spacer()
                    Picker("Sprint display", selection: $store.sprintDisplay) {
                        Text("Task").tag(BoardStore.SprintDisplay.task)
                        Text("Sprint").tag(BoardStore.SprintDisplay.sprint)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            }
            .padding(.horizontal, 2)
            .padding(.top, 2)
            .padding(.bottom, 10)
            .opacity(store.isPomodoroOn ? 1 : 0.4)
            .disabled(!store.isPomodoroOn)
            Divider().overlay(Palette.border)
            row(
                symbol: "moon.stars", tint: Palette.violet, glyph: Palette.violetText, title: "Workday ends",
                detail: "The Board says how the plan fits"
            ) {
                TimeField(date: workdayEnd, calendar: store.calendar)
            }
            Divider().overlay(Palette.border)
            row(
                symbol: store.panelSide == .right ? "sidebar.right" : "sidebar.left", tint: Palette.teal,
                glyph: Palette.tealText, title: "Panel side", detail: nil
            ) {
                Picker("Panel side", selection: $store.panelSide) {
                    Text("Left").tag(BoardStore.PanelSide.left)
                    Text("Right").tag(BoardStore.PanelSide.right)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            Divider().overlay(Palette.border)
            row(
                symbol: store.playsSounds ? "speaker.wave.2" : "speaker.slash", tint: Palette.green,
                glyph: Palette.greenText, title: "Sounds",
                detail: store.playsSounds ? "Done, breaks and time's up" : "Muted"
            ) {
                Toggle("Sounds", isOn: $store.playsSounds).labelsHidden().komodoSwitch()
            }
            Divider().overlay(Palette.border).padding(.horizontal, -Space.s3).padding(.bottom, 6)
            Button {
            } label: {
                HStack(spacing: Space.s2) {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 12, weight: .semibold))
                    Text("All settings")
                    Spacer()
                    KeyCap("⌘,")
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Palette.blueText)
                .padding(.horizontal, 10)
                .frame(height: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(true)
            .help("Settings arrive in a later milestone")
        }
        .padding(.horizontal, Space.s3)
        .padding(.top, Space.s2)
        .padding(.bottom, 10)
        .frame(width: 300)
    }

    private func minutes(_ length: TimeInterval) -> Int { Int(length / 60) }

    /// The workday's end as today's date and time, for the time field.
    private var workdayEnd: Binding<Date> {
        let day = store.today.startOfDay(in: store.calendar)
        return Binding(
            get: { day.addingTimeInterval(TimeInterval(store.workdayEnd * 60)) },
            set: {
                let parts = store.calendar.dateComponents([.hour, .minute], from: $0)
                store.workdayEnd = (parts.hour ?? 18) * 60 + (parts.minute ?? 0)
            })
    }

    private func row<Control: View>(
        symbol: String, tint: Color, glyph: Color, title: String, detail: String?,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(spacing: Space.s3) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(glyph)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.textPrimary)
                if let detail {
                    Text(detail).font(.system(size: 11.5)).foregroundStyle(Palette.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control()
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 10)
    }

    /// A minutes field with − and + beside it, clamped to the canvas's range.
    private func lengthField(
        _ label: String, length: Binding<TimeInterval>, range: ClosedRange<Int>, step: Int, accessibility: String
    ) -> some View {
        let value = Int(length.wrappedValue / 60)
        let set: (Int) -> Void = {
            length.wrappedValue = TimeInterval(min(range.upperBound, max(range.lowerBound, $0)) * 60)
        }
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        return VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(Palette.textSecondary)
            HStack(spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 13.5, weight: .bold).monospacedDigit())
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 26, alignment: .leading)
                Text("min").font(.system(size: 11.5)).foregroundStyle(Palette.textMuted)
                Spacer(minLength: 0)
                stepButton("Shorter", symbol: "minus") { set(value - step) }
                    .disabled(value <= range.lowerBound)
                stepButton("Longer", symbol: "plus") { set(value + step) }
                    .disabled(value >= range.upperBound)
            }
            .padding(.leading, 10)
            .padding(.trailing, 5)
            .frame(height: 34)
            .background(Color.white.opacity(0.04), in: shape)
            .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibility)
            .accessibilityValue("\(value)")
            .accessibilityAdjustableAction { direction in
                set(direction == .increment ? value + step : value - step)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func stepButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(title, systemImage: symbol, action: action)
            .labelStyle(.iconOnly)
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(Palette.textTertiary)
            .frame(width: 22, height: 22)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .contentShape(Rectangle())
            .buttonStyle(.plain)
    }
}

#Preview("Quick Settings") {
    QuickSettingsView(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
        .popoverSurface(tint: SpotlightTint.info)
        .padding(Space.s8)
        .background(Palette.bg)
}
