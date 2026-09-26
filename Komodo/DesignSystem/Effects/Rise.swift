import SwiftUI

/// Blur-rise enter (DESIGN_SYSTEM §5.1): new cards rise 12 pt out of a 6 pt blur.
/// `amount` is 1 when hidden and 0 when settled.
struct RiseModifier: ViewModifier {
    var amount: Double

    private static let distance: CGFloat = 12
    private static let blur: CGFloat = 6
    private static let shrink = 0.015

    func body(content: Content) -> some View {
        content
            .opacity(1 - amount)
            .offset(y: Self.distance * amount)
            .blur(radius: Self.blur * amount)
            .scaleEffect(1 - Self.shrink * amount)
    }
}

extension AnyTransition {
    /// Reduce Motion drops the movement and blur and keeps the fade.
    static func rise(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .modifier(active: RiseModifier(amount: 1), identity: RiseModifier(amount: 0))
    }
}

extension Animation {
    /// `Motion.enter`, delayed for the item's place in a staggered list.
    static func enter(index: Int) -> Animation {
        Motion.enter.delay(Double(index) * Motion.enterStagger)
    }
}

#Preview("Rise") {
    struct Demo: View {
        @State private var shown = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        var body: some View {
            VStack(spacing: Space.s3) {
                Button(shown ? "Reset" : "Add cards") { shown.toggle() }
                ForEach(0..<3, id: \.self) { index in
                    if shown {
                        Text("New card enters")
                            .font(Typography.body)
                            .foregroundStyle(Palette.textPrimary)
                            .padding(Space.s4)
                            .frame(width: 240)
                            .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.tile))
                            .transition(.rise(reduceMotion: reduceMotion))
                            .animation(.enter(index: index), value: shown)
                    }
                }
            }
            .frame(height: 260, alignment: .top)
            .padding(Space.s8)
            .background(Palette.bg)
        }
    }
    return Demo()
}
