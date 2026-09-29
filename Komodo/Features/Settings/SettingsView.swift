import KomodoCore
import SwiftUI

/// The Settings window (DESIGN_SYSTEM §13.15, Settings.png): a 236 pt sidebar of pages with a search field, and
/// the page under a 52 pt title bar. Every change applies as it's made; there's no Save button.
struct SettingsView: View {
    @Bindable var store: BoardStore

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(store: store)
                .frame(width: Layout.settingsSidebar)
            VStack(spacing: 0) {
                Text(store.settingsSection.title)
                    .font(Typography.heading)
                    .foregroundStyle(Palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .frame(height: 52)
                    .background(Palette.panel.opacity(0.6))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
                    }
                ScrollView {
                    page
                        .padding(.horizontal, 28)
                        .padding(.top, Space.s1)
                        .padding(.bottom, 36)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .environment(\.settingsTint, store.settingsSection.spotlight)
                        .id(store.settingsSection)
                        .transition(.opacity)
                }
                .scrollIndicators(.never)
                .animation(Motion.base, value: store.settingsSection)
            }
            .background(Palette.bg)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var page: some View {
        switch store.settingsSection {
        case .general: SettingsGeneralPage(store: store)
        case .focus: SettingsFocusPage(store: store)
        default: EmptyView()
        }
    }
}

/// `.st-side`: search, the pages in three groups, and "Changes apply instantly" at the foot.
private struct SettingsSidebar: View {
    @Bindable var store: BoardStore
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            KomodoTextField("Search", text: $query, variant: .search, density: .compact)
                .padding(.horizontal, 2)
                .padding(.bottom, 10)
            ForEach(Array(visibleGroups.enumerated()), id: \.offset) { index, group in
                if index > 0 {
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 1)
                        .padding(.horizontal, Space.s2)
                        .padding(.vertical, 7)
                }
                ForEach(group) { section in
                    SettingsNavRow(section: section, isSelected: store.settingsSection == section) {
                        store.settingsSection = section
                    }
                    .disabled(section.comingIn != nil)
                    .help(section.comingIn ?? "")
                }
            }
            Spacer(minLength: Space.s4)
            Label("Changes apply instantly", systemImage: "checkmark")
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.textMuted)
                .labelStyle(SettingsFooterLabelStyle())
                .padding(.horizontal, Space.s2)
        }
        .padding(.top, 46)
        .padding(.horizontal, 10)
        .padding(.bottom, Space.s3)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            LinearGradient(colors: [Palette.raised.opacity(0.97), Palette.card], startPoint: .top, endPoint: .bottom)
        )
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1)
        }
    }

    private var visibleGroups: [[SettingsSection]] {
        SettingsSection.groups.map { $0.filter { $0.matches(query) } }.filter { !$0.isEmpty }
    }
}

private struct SettingsFooterLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.green)
            configuration.title
        }
    }
}

/// `.st-nav`: a 22 pt tinted icon square and the page's name. The selected page fills its square and glows.
private struct SettingsNavRow: View {
    var section: SettingsSection
    var isSelected: Bool
    var action: () -> Void

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                icon
                Text(section.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? Palette.textPrimary : Palette.textTertiary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Space.s2)
            .frame(height: 32)
            .background(
                Color.white.opacity(isSelected ? 0.08 : isHovered ? 0.04 : 0),
                in: RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
            )
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(Motion.fast, value: isHovered)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var icon: some View {
        let shape = RoundedRectangle(cornerRadius: 6.5, style: .continuous)
        let tint = section.tint
        return Group {
            if section == .about {
                KomodoMarkShape()
                    .stroke(Palette.lime, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: section.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Palette.onAccent : tint)
            }
        }
        .frame(width: 22, height: 22)
        .background(section == .about ? Palette.raised : tint.opacity(isSelected ? 1 : 0.14), in: shape)
        .overlay(
            shape.strokeBorder(section == .about ? Palette.lime.opacity(isSelected ? 0.6 : 0.2) : tint.opacity(0.3))
        )
        .shadow(color: isSelected ? tint.opacity(0.85) : .clear, radius: 8)
        .scaleEffect(isSelected ? 1.06 : 1)
        .animation(Motion.spring, value: isSelected)
    }
}

#Preview("Settings · General") {
    SettingsView(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
        .frame(width: 1100, height: 760)
}
