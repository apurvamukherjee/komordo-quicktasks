import SwiftUI

/// A 7 pt status dot with its label, so state never relies on color alone (DESIGN_SYSTEM §8).
struct StatusDot: View {
    enum Status {
        case active
        /// Scanning, exporting: pings teal.
        case working
        case paused
        case attention
        case offline

        var color: Color {
            switch self {
            case .active: Palette.green
            case .working: Palette.teal
            case .paused, .offline: Palette.textMuted
            case .attention: Palette.danger
            }
        }

        var pings: Bool { self == .active || self == .working }
    }

    var status: Status
    var label: String

    var body: some View {
        HStack(spacing: 7) {
            dot.frame(width: 7, height: 7)
            Text(label)
        }
        .font(.system(size: 12.5))
        .foregroundStyle(Palette.textTertiary)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var dot: some View {
        switch status {
        case .offline:
            Circle().strokeBorder(status.color, lineWidth: 1.5)
        case .attention:
            Circle().fill(status.color).shadow(color: status.color.opacity(0.9), radius: 4)
        default:
            if status.pings {
                Circle().fill(status.color).ping(status.color)
            } else {
                Circle().fill(status.color)
            }
        }
    }
}

#Preview("Status dots") {
    HStack(spacing: 18) {
        StatusDot(status: .active, label: "Active")
        StatusDot(status: .working, label: "Scanning")
        StatusDot(status: .paused, label: "Paused")
        StatusDot(status: .attention, label: "Needs attention")
        StatusDot(status: .offline, label: "Offline")
    }
    .padding(Space.s8)
    .background(Palette.bg)
}
