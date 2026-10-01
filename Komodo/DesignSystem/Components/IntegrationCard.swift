import SwiftUI

/// DESIGN_SYSTEM §10.10 (`.st-card`): a 30 pt logo tile, the name and its status, a muted line, and the account
/// and button along the foot, lit by its own spotlight.
struct IntegrationCard<Logo: View, Footer: View>: View {
    enum Status: Equatable {
        case none
        case active(String)
        case attention
        case off
        case comingSoon
    }

    var name: String
    var detail: Text
    var status: Status = .none
    var tint: Color
    @ViewBuilder var logo: Logo
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                logo
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(width: 30, height: 30)
                    .background(
                        LinearGradient(colors: [Palette.raised, Palette.card], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                Text(name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                badge
            }
            detail
                .font(.system(size: 12))
                .foregroundStyle(Palette.textTertiary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 41)
            Spacer(minLength: 0)
            HStack(spacing: Space.s2) { footer }
                .padding(.leading, 41)
        }
        .padding(Space.s4)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .spotlight(status == .attention ? Palette.danger : tint, radius: Radius.tile) { TileSurface() }
        .opacity(status == .comingSoon ? 0.6 : 1)
    }

    @ViewBuilder private var badge: some View {
        switch status {
        case .none: EmptyView()
        case .active(let label): dot(label, color: Palette.green, text: Palette.greenText)
        case .attention: dot("Needs attention", color: Palette.danger, text: Palette.dangerText)
        case .off: Chip("Off", tint: .outline, size: .compact)
        case .comingSoon: Chip("Coming soon", size: .compact)
        }
    }

    private func dot(_ label: String, color: Color, text: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7).shadow(color: color.opacity(0.8), radius: 4)
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(text)
        }
    }
}

#Preview("Integration cards") {
    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
        IntegrationCard(
            name: "Calendar import", detail: Text("Show events from the calendars on this Mac as tasks."),
            status: .active("Active"), tint: Palette.blue
        ) {
            Image(systemName: "calendar")
        } footer: {
            Text("3 calendars").font(.system(size: 12)).foregroundStyle(Palette.textBody)
            Spacer()
            Button("Sync now") {}.buttonStyle(.komodo(.secondary, size: .small))
        }
        IntegrationCard(
            name: "Calendar import", detail: Text("Calendar access is off.").foregroundColor(Palette.dangerText),
            status: .attention, tint: Palette.blue
        ) {
            Image(systemName: "calendar")
        } footer: {
            Spacer()
            Button("Open System Settings") {}.buttonStyle(.komodo(.dangerOutline, size: .small))
        }
        IntegrationCard(
            name: "Notion", detail: Text("Sync a database."), status: .comingSoon, tint: Palette.textTertiary
        ) {
            Text("N")
        } footer: {
            EmptyView()
        }
        IntegrationCard(
            name: "Local MCP server",
            detail: Text("Let Claude Desktop, Claude Code, and Raycast use Komodo on this Mac."),
            status: .off, tint: Palette.cyan
        ) {
            Image(systemName: "chevron.right")
        } footer: {
            Spacer()
            Button("Set up") {}.buttonStyle(.komodo(.secondary, size: .small))
        }
    }
    .frame(width: 700)
    .padding(Space.s6)
    .background(Palette.bg)
}
