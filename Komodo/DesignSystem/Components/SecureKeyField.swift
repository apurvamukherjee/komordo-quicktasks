import SwiftUI

/// A secret with **Show** and **Test** (DESIGN_SYSTEM §10.6). The test result is shown inline under the field.
struct SecureKeyField: View {
    enum TestState: Equatable {
        case idle
        case testing
        case valid
        case invalid(String)
    }

    var placeholder: String
    @Binding var secret: String
    var testState: TestState
    var onTest: () -> Void

    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Group {
                    if isRevealed {
                        TextField(placeholder, text: $secret)
                    } else {
                        SecureField(placeholder, text: $secret)
                    }
                }
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Palette.textPrimary)
                .focused($isFocused)
                .focusEffectDisabled()
                Button(isRevealed ? "Hide" : "Show") { isRevealed.toggle() }
                    .buttonStyle(.komodo(.ghost, size: .small))
                Button("Test", action: onTest)
                    .buttonStyle(.komodo(.secondary, size: .small, isBusy: testState == .testing))
                    .disabled(secret.isEmpty)
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .frame(height: 36)
            .background(isFocused ? Palette.card : Color.white.opacity(0.04), in: shape)
            .overlay(shape.strokeBorder(borderColor, lineWidth: 1))
            result
        }
    }

    private var borderColor: Color {
        if case .invalid = testState { return Palette.danger.opacity(0.7) }
        return isFocused ? Palette.teal.opacity(0.6) : Color.white.opacity(0.08)
    }

    @ViewBuilder private var result: some View {
        switch testState {
        case .idle, .testing:
            EmptyView()
        case .valid:
            Label("Key works", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Palette.greenText)
        case .invalid(let message):
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Palette.dangerText)
        }
    }
}

#Preview("Secure key field") {
    struct Demo: View {
        @State private var secret = "GOCSPX-4f2a9c1e7b"

        var body: some View {
            VStack(alignment: .leading, spacing: Space.s5) {
                SecureKeyField(placeholder: "Client secret", secret: $secret, testState: .idle) {}
                SecureKeyField(placeholder: "Client secret", secret: $secret, testState: .testing) {}
                SecureKeyField(placeholder: "Client secret", secret: $secret, testState: .valid) {}
                SecureKeyField(
                    placeholder: "Client secret", secret: $secret,
                    testState: .invalid("Google rejected this secret. Copy it again from Cloud Console.")
                ) {}
            }
            .frame(width: 420)
            .padding(Space.s8)
            .background(Palette.bg)
        }
    }
    return Demo()
}
