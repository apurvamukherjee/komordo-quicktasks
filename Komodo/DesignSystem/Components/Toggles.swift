import SwiftUI

extension View {
    /// The system switch tinted success green (DESIGN_SYSTEM §10.6). Checkboxes stay native and pick up the
    /// teal accent from the asset catalog, so they need nothing extra.
    func komodoSwitch() -> some View {
        toggleStyle(.switch).tint(Palette.green)
    }
}

#Preview("Toggles") {
    struct Demo: View {
        @State private var pomodoros = true
        @State private var sound = false
        @State private var feedback = true

        var body: some View {
            HStack(spacing: 28) {
                Toggle("Pomodoros", isOn: $pomodoros).komodoSwitch()
                Toggle("Success sound", isOn: $sound).komodoSwitch()
                Toggle("Collect feedback", isOn: $feedback).toggleStyle(.checkbox)
                Toggle("Disabled", isOn: .constant(true)).komodoSwitch().disabled(true)
            }
            .font(.system(size: 13))
            .foregroundStyle(Palette.textPrimary)
            .padding(Space.s8)
            .background(Palette.bg)
        }
    }
    return Demo()
}
