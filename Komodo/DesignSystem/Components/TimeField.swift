import AppKit
import SwiftUI

/// The 116 pt time field from the Schedule canvas: a clock, the time in monospaced digits and a stepper, inside a
/// Komodo field. It wraps an unbezeled `NSDatePicker` because SwiftUI's picker always draws its own bezel, and the
/// native one keeps typing and the arrow keys.
struct TimeField: View {
    @Binding var date: Date
    var calendar: Calendar = .current

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.blueText)
            BarePicker(date: $date, calendar: calendar)
        }
        .padding(.leading, 9)
        .padding(.trailing, Space.s1)
        .frame(width: 116, height: 30, alignment: .leading)
        .background(Color.white.opacity(0.04), in: shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}

private struct BarePicker: NSViewRepresentable {
    @Binding var date: Date
    var calendar: Calendar

    func makeNSView(context: Context) -> NSDatePicker {
        let picker = NSDatePicker()
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = .hourMinute
        picker.isBezeled = false
        picker.isBordered = false
        picker.drawsBackground = false
        picker.focusRingType = .none
        picker.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        picker.textColor = .white
        picker.setAccessibilityLabel("Time")
        picker.target = context.coordinator
        picker.action = #selector(Coordinator.changed(_:))
        return picker
    }

    func updateNSView(_ picker: NSDatePicker, context: Context) {
        context.coordinator.date = $date
        picker.calendar = calendar
        picker.timeZone = calendar.timeZone
        if picker.dateValue != date { picker.dateValue = date }
    }

    func makeCoordinator() -> Coordinator { Coordinator(date: $date) }

    final class Coordinator: NSObject {
        var date: Binding<Date>

        init(date: Binding<Date>) { self.date = date }

        @MainActor @objc func changed(_ sender: NSDatePicker) { date.wrappedValue = sender.dateValue }
    }
}

#Preview("Time field") {
    struct Demo: View {
        @State private var date = Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: .now) ?? .now

        var body: some View {
            TimeField(date: $date)
                .padding(Space.s8)
                .background(Palette.raised)
        }
    }
    return Demo()
}
