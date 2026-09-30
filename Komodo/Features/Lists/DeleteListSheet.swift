import KomodoCore
import SwiftUI

/// Delete's typed confirm (FEATURES §4.1): Delete list stays off until the field reads the list's name.
struct DeleteListSheet: View {
    var list: TaskList
    var taskCount: Int
    var cancel: () -> Void
    var delete: () -> Void

    @State private var typed = ""

    private var isArmed: Bool { typed.trimmingCharacters(in: .whitespaces) == list.name }

    private var summary: String {
        switch taskCount {
        case 0: "The list moves to Trash for 30 days."
        case 1: "The list and its task move to Trash for 30 days."
        default: "The list and its \(taskCount) tasks move to Trash for 30 days."
        }
    }

    var body: some View {
        FormSheet(symbol: "trash", tint: Palette.danger, glyph: Palette.dangerText) {
            Text("Delete “\(list.name)”?")
        } content: {
            Text(summary)
            VStack(alignment: .leading, spacing: 6) {
                (Text("Type ") + Text(list.name).bold().foregroundColor(Palette.textPrimary) + Text(" to confirm"))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)
                KomodoTextField(list.name, text: $typed, focusesOnAppear: true)
                    .accessibilityLabel("Type \(list.name) to confirm")
            }
        } actions: {
            Button("Cancel", action: cancel)
                .buttonStyle(.komodo(.secondary))
                .keyboardShortcut(.cancelAction)
            Button("Delete list", action: delete)
                .buttonStyle(.komodo(.danger))
                .keyboardShortcut(.defaultAction)
                .disabled(!isArmed)
        }
    }
}

#Preview("Delete list") {
    DeleteListSheet(list: TaskList(id: "growth", name: "Growth", color: "amber"), taskCount: 4, cancel: {}, delete: {})
}
