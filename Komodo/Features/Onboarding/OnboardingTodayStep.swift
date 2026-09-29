import KomodoCore
import SwiftUI

/// Step 5 (DESIGN_SYSTEM §13.1): one task per line, each line's parsed EST as a chip at its end, and the count and
/// total underneath.
struct OnboardingTodayStep: View {
    @Binding var text: String
    /// ⌘Return: the text view takes the key before any button's shortcut sees it, so it's caught here.
    var onContinue: () -> Void = {}

    /// The canvas's 30 pt rows, which the chip column lines up with.
    private static let rowHeight: CGFloat = 30
    private static let font = NSFont.systemFont(ofSize: 13.5)

    /// The lines that become tasks: trimmed, blank ones dropped.
    static func lines(in text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var rows: [EstimateParser.Result?] {
        text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : EstimateParser.parse(trimmed)
        }
    }

    private var summary: String {
        let parsed = rows.compactMap { $0 }
        guard !parsed.isEmpty else { return "Nothing yet. Skip and add tasks later." }
        let total = parsed.compactMap(\.estimate).reduce(0, +)
        let missing = parsed.filter { $0.estimate == nil }.count
        var summary = "\(parsed.count) task\(parsed.count == 1 ? "" : "s")"
        if total > 0 { summary += " · Est \(DurationFormat.short(total))" }
        if missing > 0 { summary += " · \(missing) without EST" }
        return summary
    }

    @FocusState private var isFocused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            Text("What do you want to finish today?")
                .font(.system(size: 24, weight: .heavy))
                .tracking(-0.6)
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, Space.s4)
            Text("One task per line. Add a time like “45m”.")
                .font(.system(size: 13.5))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 6)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(Font(Self.font))
                    .lineSpacing(Self.rowHeight - Self.font.boundingRectForFont.height)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.never)
                    .focused($isFocused)
                    .onKeyPress(.return, phases: .down) { press in
                        guard press.modifiers.contains(.command) else { return .ignored }
                        onContinue()
                        return .handled
                    }
                    .padding(.trailing, 112)
                    .accessibilityLabel("Tasks for today, one per line")
                if text.isEmpty {
                    Text("Write launch email 45m")
                        .font(Font(Self.font))
                        .foregroundStyle(Palette.textMuted)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
                chips
            }
            .padding(.leading, 9)
            .padding(.trailing, 10)
            .padding(.top, Space.s2)
            .frame(height: 196)
            .background(isFocused ? Palette.raised : Color.white.opacity(0.035), in: shape)
            .overlay(shape.strokeBorder(isFocused ? Palette.teal.opacity(0.6) : Color.white.opacity(0.09)))
            .background(shape.stroke(Palette.teal.opacity(isFocused ? 0.12 : 0), lineWidth: 8))
            .padding(.top, Space.s4)
            HStack(spacing: 10) {
                Text(summary)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(rows.contains { $0 != nil } ? Palette.textBody : Palette.textMuted)
                if rows.contains(where: { $0 != nil }) {
                    Chip("Goes to Today", tint: .lime, icon: "sun.max", size: .compact)
                }
            }
            .padding(.top, Space.s3)
            HStack(spacing: 6) {
                KeyCap("Return")
                Text("adds a line")
                Text("·")
                KeyCap("⌘Return")
                Text("continues")
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Palette.textMuted)
            .padding(.top, Space.s2)
        }
        .onAppear { isFocused = true }
    }

    /// `.ob-chipcol`: a lime chip with the parsed EST, or "No EST", level with each line.
    private var chips: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                Group {
                    if let row {
                        if let estimate = row.estimate {
                            Chip(DurationFormat.short(estimate), tint: .lime, icon: "clock", size: .compact)
                        } else {
                            Chip("No EST", tint: .outline, size: .compact)
                        }
                    }
                }
                .frame(height: Self.rowHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topTrailing)
        .offset(y: -8)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Today step") {
    struct Demo: View {
        @State private var text = "Write launch email 45m\nReview the API PR 30m\nGym 1h"

        var body: some View {
            OnboardingTodayStep(text: $text)
                .padding(Space.s6)
                .frame(width: 560)
                .background(Palette.panel)
        }
    }
    return Demo()
}
