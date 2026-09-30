import KomodoCore
import SwiftUI

/// New list, Rename and Color & Icon (FEATURES §4.1): a name of 1–60 characters, one of the eight colors, and a
/// badge that is the name's first letter unless an emoji or another letter is typed.
struct ListEditorSheet: View {
    var list: TaskList?
    var save: (_ name: String, _ color: ListColor, _ badge: String?) -> Void
    var cancel: () -> Void

    @State private var name: String
    @State private var color: ListColor
    @State private var badge: String

    init(
        list: TaskList?, save: @escaping (_ name: String, _ color: ListColor, _ badge: String?) -> Void,
        cancel: @escaping () -> Void
    ) {
        self.list = list
        self.save = save
        self.cancel = cancel
        _name = State(initialValue: list?.name ?? "")
        _color = State(initialValue: list.flatMap { ListColor(rawValue: $0.color) } ?? .lime)
        // A badge that is just the first letter stays empty, so it follows a rename.
        let custom = list.map { $0.letter != TaskList.defaultLetter(for: $0.name) } ?? false
        _badge = State(initialValue: custom ? list?.letter ?? "" : "")
    }

    private var isValid: Bool { TaskList.validName(name) != nil }
    private var isTooLong: Bool { name.trimmingCharacters(in: .whitespaces).count > TaskList.nameLimit }
    private var shownBadge: String {
        badge.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() }
            ?? TaskList.defaultLetter(for: name.isEmpty ? "?" : name)
    }

    var body: some View {
        FormSheet(symbol: list == nil ? "plus" : "pencil", tint: Palette.lime, glyph: Palette.limeText) {
            Text(list == nil ? "New list" : "Edit list")
        } content: {
            VStack(alignment: .leading, spacing: Space.s4) {
                field("NAME") {
                    KomodoTextField(
                        "Work", text: $name, error: isTooLong ? "Keep it to 60 characters." : nil,
                        focusesOnAppear: true
                    )
                    .onSubmit(submit)
                }
                field("COLOR") {
                    HStack(spacing: 10) {
                        ForEach(ListColor.allCases, id: \.self) { swatch in
                            ColorSwatch(color: swatch, isSelected: swatch == color) { color = swatch }
                        }
                    }
                }
                field("BADGE") {
                    HStack(spacing: Space.s3) {
                        ListBadge(letter: shownBadge, color: color, side: 36)
                        KomodoTextField("First letter, or an emoji", text: $badge)
                            .frame(width: 220)
                            // One character: the latest one typed replaces the last.
                            .onChange(of: badge) { if badge.count > 1 { badge = String(badge.suffix(1)) } }
                    }
                }
            }
        } actions: {
            Button("Cancel", action: cancel)
                .buttonStyle(.komodo(.secondary))
                .keyboardShortcut(.cancelAction)
            Button(list == nil ? "Create list" : "Save", action: submit)
                .buttonStyle(.komodo(.primary))
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
        }
    }

    private func submit() {
        guard isValid else { return }
        save(name, color, badge.isEmpty ? nil : badge)
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Typography.label)
                .tracking(Typography.Tracking.label)
                .foregroundStyle(Palette.textMuted)
            content()
        }
    }
}

/// A 24 pt list color; the chosen one wears a white ring.
private struct ColorSwatch: View {
    var color: ListColor
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.fill)
                .frame(width: 24, height: 24)
                .padding(3)
                .overlay(Circle().strokeBorder(Color.white.opacity(isSelected ? 0.9 : 0), lineWidth: 2))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.rawValue.capitalized)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview("New list") {
    ListEditorSheet(list: nil, save: { _, _, _ in }, cancel: {})
}

#Preview("Edit list") {
    ListEditorSheet(
        list: TaskList(id: "side", name: "Side project", color: "blue", letter: "🚀"), save: { _, _, _ in }, cancel: {})
}
