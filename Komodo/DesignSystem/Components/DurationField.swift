import KomodoCore
import SwiftUI

/// A 56 pt `HH:MM` field for estimates (DESIGN_SYSTEM §10.6). Edits commit on Return or when focus leaves;
/// text that doesn't parse keeps the old value and shows the danger edge until it's fixed.
struct DurationField: View {
    @Binding var duration: TimeInterval
    /// For fields that appear on demand, like time taken in the inspector.
    var focusesOnAppear = false

    @State private var draft: String?
    @FocusState private var isFocused: Bool

    private var text: Binding<String> {
        Binding(
            get: { draft ?? DurationFormat.hoursMinutes(duration) },
            set: { draft = $0 }
        )
    }

    private var isInvalid: Bool {
        guard let draft else { return false }
        return DurationFormat.parseHoursMinutes(draft) == nil
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        TextField("00:00", text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .semibold).monospacedDigit())
            .multilineTextAlignment(.center)
            .foregroundStyle(Palette.textPrimary)
            .focused($isFocused)
            .focusEffectDisabled()
            .frame(width: 56, height: 28)
            .background(isFocused ? Palette.card : Color.white.opacity(0.04), in: shape)
            .overlay(shape.strokeBorder(borderColor, lineWidth: 1))
            .onSubmit(commit)
            .onAppear { if focusesOnAppear { isFocused = true } }
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            .accessibilityLabel("Estimate, hours and minutes")
    }

    private var borderColor: Color {
        if isInvalid { return Palette.danger.opacity(0.7) }
        return isFocused ? Palette.teal.opacity(0.6) : Color.white.opacity(0.08)
    }

    private func commit() {
        guard let draft, let parsed = DurationFormat.parseHoursMinutes(draft) else { return }
        duration = parsed
        self.draft = nil
    }
}

#Preview("Duration field") {
    struct Demo: View {
        @State private var estimate: TimeInterval = 5_400

        var body: some View {
            HStack(spacing: Space.s3) {
                DurationField(duration: $estimate)
                Text(DurationFormat.short(estimate))
                    .font(Typography.small)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(Space.s8)
            .background(Palette.bg)
        }
    }
    return Demo()
}
