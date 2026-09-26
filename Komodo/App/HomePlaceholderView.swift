import SwiftUI

// Stands in for the Board until milestone M6.
struct HomePlaceholderView: View {
    var body: some View {
        Text("Komodo")
            .font(Typography.display)
            .tracking(Typography.Tracking.display)
            .foregroundStyle(Palette.liveGradient)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.bg)
    }
}

#Preview {
    HomePlaceholderView()
        .frame(width: Layout.homeDefault.width, height: Layout.homeDefault.height)
}
