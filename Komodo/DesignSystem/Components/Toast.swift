import SwiftUI

/// A short message at the bottom center of the window (DESIGN_SYSTEM §10.9), with an optional lime action
/// such as **Undo**.
struct Toast: Identifiable {
    enum Kind {
        case success
        case info
        case error

        var symbol: String {
            switch self {
            case .success: "checkmark"
            case .info: "info"
            case .error: "exclamationmark"
            }
        }

        var tint: Color {
            switch self {
            case .success: Palette.green
            case .info: Palette.teal
            case .error: Palette.danger
            }
        }

        var glyph: Color {
            switch self {
            case .success: Palette.greenText
            case .info: Palette.tealText
            case .error: Palette.redText
            }
        }
    }

    struct Action {
        var title: String
        var shortcut: String?
        var perform: () -> Void
    }

    let id = UUID()
    var kind: Kind = .success
    var message: String
    var detail: String?
    var action: Action?
}

/// Holds the visible toasts: at most three, each leaving on its own after five seconds.
@MainActor @Observable final class ToastCenter {
    static let lifetime: Duration = .seconds(5)
    static let maxVisible = 3

    private(set) var toasts: [Toast] = []

    func show(_ toast: Toast) {
        toasts.append(toast)
        if toasts.count > Self.maxVisible { toasts.removeFirst(toasts.count - Self.maxVisible) }
        let id = toast.id
        Task { [weak self] in
            do {
                try await Task.sleep(for: Self.lifetime)
            } catch {
                // Cancelled with the app or view; nothing is left to dismiss.
                return
            }
            self?.dismiss(id)
        }
    }

    func dismiss(_ id: UUID) {
        toasts.removeAll { $0.id == id }
    }
}

struct ToastView: View {
    var toast: Toast
    var onDismiss: () -> Void

    @State private var drained = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        HStack(spacing: Space.s3) {
            Image(systemName: toast.kind.symbol)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(toast.kind.glyph)
                .frame(width: 24, height: 24)
                .background(toast.kind.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.chip))
            Text(toast.message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
            if let detail = toast.detail {
                Text(detail).font(.system(size: 12)).foregroundStyle(Palette.textMuted).lineLimit(1)
            }
            if let action = toast.action {
                Button {
                    action.perform()
                    onDismiss()
                } label: {
                    HStack(spacing: 7) {
                        Text(action.title)
                        if let shortcut = action.shortcut { KeyCap(shortcut, tint: Palette.lime) }
                    }
                }
                .buttonStyle(ToastActionStyle())
                .padding(.leading, 4)
            }
            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .buttonStyle(.icon(.compact))
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .frame(height: 50)
        .overlay(alignment: .bottom) { drain }
        .spotlight(SpotlightTint.today, radius: 12, lifts: false) {
            shape.fill(Palette.raised)
                .overlay(shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        }
        .shadow(color: .black.opacity(0.95), radius: 25, y: 12)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 5)) { drained = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isStaticText)
    }

    /// The lime line that drains over the toast's five seconds, so its exit is never a surprise.
    private var drain: some View {
        Capsule()
            .fill(Color.white.opacity(0.07))
            .frame(height: 2)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(Palette.lime)
                        .frame(width: drained ? 0 : geo.size.width)
                        .shadow(color: Palette.lime.opacity(0.8), radius: 4)
                }
            }
            .padding(.horizontal, Space.s3)
            .padding(.bottom, 4)
    }
}

private struct ToastActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Palette.limeText)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(
                Palette.lime.opacity(configuration.isPressed ? 0.2 : 0.1),
                in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(Motion.spring, value: configuration.isPressed)
    }
}

extension View {
    /// Stacks the center's toasts at the bottom center of this view, newest at the bottom.
    func toastOverlay(_ center: ToastCenter) -> some View {
        overlay(alignment: .bottom) {
            VStack(spacing: Space.s2) {
                ForEach(center.toasts) { toast in
                    ToastView(toast: toast) { center.dismiss(toast.id) }
                        .transition(.scale(scale: 0.94).combined(with: .opacity).combined(with: .offset(y: 6)))
                }
            }
            .padding(.bottom, 26)
            .animation(Motion.spring, value: center.toasts.map(\.id))
        }
    }
}

#Preview("Toasts") {
    struct Demo: View {
        @State private var center = ToastCenter()

        var body: some View {
            VStack(spacing: Space.s4) {
                ToastView(
                    toast: Toast(
                        message: "Moved to Today", detail: "Wireframes: floating timer pill",
                        action: .init(title: "Undo", shortcut: "⌘Z") {})
                ) {}
                ToastView(toast: Toast(kind: .info, message: "Backup saved")) {}
                ToastView(toast: Toast(kind: .error, message: "Backup failed", detail: "Folder not found")) {}
                Button("Show toast") {
                    center.show(Toast(message: "Task completed", action: .init(title: "Undo", shortcut: "⌘Z") {}))
                }
                .buttonStyle(.komodo(.primary))
            }
            .frame(width: 640, height: 480)
            .background(Palette.bg)
            .toastOverlay(center)
        }
    }
    return Demo()
}
