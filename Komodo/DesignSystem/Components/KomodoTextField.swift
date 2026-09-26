import SwiftUI

/// Komodo's text field (DESIGN_SYSTEM §10.6): white 4% fill and a hairline, a teal edge and soft ring while
/// focused, and a danger edge plus an 11 pt message on error.
struct KomodoTextField<Accessory: View>: View {
    enum Variant {
        case standard
        /// Leading magnifying glass.
        case search
        /// SF Mono, for IDs and keys.
        case monospaced
    }

    enum Density {
        /// 36 pt.
        case regular
        /// 34 pt, matching the toolbar buttons beside it.
        case toolbar
        /// 28 pt, inside dense rows.
        case compact

        var height: CGFloat {
            switch self {
            case .regular: 36
            case .toolbar: 34
            case .compact: 28
            }
        }
    }

    var placeholder: String
    @Binding var text: String
    var variant: Variant = .standard
    var density: Density = .regular
    var error: String?
    /// Takes keyboard focus as soon as it appears, for inline editors.
    var focusesOnAppear = false
    @ViewBuilder var accessory: Accessory

    @FocusState private var isFocused: Bool
    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.control, style: .continuous)
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 9) {
                if variant == .search {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.textMuted)
                }
                TextField(text: $text, prompt: Text(placeholder).foregroundStyle(Palette.textMuted)) {
                    Text(placeholder)
                }
                .textFieldStyle(.plain)
                .font(variant == .monospaced ? .system(size: 13, design: .monospaced) : .system(size: 13))
                .foregroundStyle(Palette.textPrimary)
                .focused($isFocused)
                // The field draws its own teal ring, so the system one would double up.
                .focusEffectDisabled()
                accessory
            }
            .padding(.horizontal, 12)
            .frame(height: density.height)
            .background(isFocused ? Palette.card : Color.white.opacity(0.04), in: shape)
            .overlay(shape.strokeBorder(borderColor, lineWidth: 1))
            .background(shape.stroke(ringColor, lineWidth: 8))
            .opacity(isEnabled ? 1 : 0.4)
            .animation(Motion.fast, value: isFocused)
            .onHover { isHovered = $0 }
            .onAppear { if focusesOnAppear { isFocused = true } }
            if let error {
                Text(error).font(.system(size: 11)).foregroundStyle(Palette.dangerText)
            }
        }
    }

    private var borderColor: Color {
        if error != nil { return Palette.danger.opacity(0.7) }
        if isFocused { return Palette.teal.opacity(0.6) }
        return Color.white.opacity(isHovered ? 0.14 : 0.08)
    }

    private var ringColor: Color {
        if error != nil { return Palette.danger.opacity(0.1) }
        return isFocused ? Palette.teal.opacity(0.12) : .clear
    }
}

extension KomodoTextField where Accessory == EmptyView {
    init(
        _ placeholder: String, text: Binding<String>, variant: Variant = .standard, density: Density = .regular,
        error: String? = nil, focusesOnAppear: Bool = false
    ) {
        self.init(
            placeholder: placeholder, text: text, variant: variant, density: density, error: error,
            focusesOnAppear: focusesOnAppear, accessory: { EmptyView() })
    }
}

#Preview("Text fields") {
    struct Demo: View {
        @State private var title = ""
        @State private var focused = "Write launch email 45m"
        @State private var clientID = "1234-abc"
        @State private var search = ""

        var body: some View {
            VStack(alignment: .leading, spacing: Space.s4) {
                HStack(alignment: .top, spacing: 10) {
                    KomodoTextField("Task title", text: $title)
                    KomodoTextField(placeholder: "Task title", text: $focused) {
                        Chip("45min", tint: .lime, size: .compact)
                    }
                    KomodoTextField(
                        "Client ID", text: $clientID, variant: .monospaced, error: "That client ID isn't valid.")
                }
                KomodoTextField("Search tasks…", text: $search, variant: .search, density: .compact)
                    .frame(width: 240)
            }
            .frame(width: 720)
            .padding(Space.s8)
            .background(Palette.bg)
        }
    }
    return Demo()
}
