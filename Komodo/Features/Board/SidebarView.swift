import KomodoCore
import SwiftUI

/// The Home window's sidebar (DESIGN_SYSTEM §12): brand, navigation, lists with open counts, and today's focus.
struct SidebarView: View {
    @Bindable var store: BoardStore
    /// The list row a dragged list is over.
    @State private var dropTarget: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            brand
            NavRow(
                title: "Home", symbol: "house", shortcut: "⌘1",
                isSelected: store.page == .board && store.selectedListID != nil
            ) {
                if store.page != .board || store.selectedListID == nil { store.showBoard() }
            }
            NavRow(
                title: "All lists", symbol: "square.grid.2x2",
                isSelected: store.page == .board && store.selectedListID == nil
            ) {
                store.showList(nil)
            }
            NavRow(title: "Reports", symbol: "chart.bar.xaxis", shortcut: "⌘2", isSelected: store.page == .reports) {
                store.showReports()
            }

            HStack {
                Text("LISTS")
                    .font(Typography.label)
                    .tracking(Typography.Tracking.label)
                    .foregroundStyle(Palette.textMuted)
                Spacer()
                Button("Create list", systemImage: "plus") { store.listSheet = .create }
                    .buttonStyle(.icon(.compact))
                    .help("Create new list")
            }
            .padding(.horizontal, 10)
            .padding(.top, 18)
            .padding(.bottom, Space.s2)

            ForEach(store.lists) { list in
                ListRow(
                    list: list, count: store.openCount(listID: list.id),
                    isSelected: store.page == .board && store.selectedListID == list.id
                ) {
                    store.showList(list.id)
                }
                .contextMenu { listMenu(list) }
                .draggable(list.id)
                // Text dragged in from elsewhere isn't a list id, so it's refused.
                .dropDestination(for: String.self) { dropped, _ in
                    guard let dragged = dropped.first, store.lists.contains(where: { $0.id == dragged }) else {
                        return false
                    }
                    withAnimation(Motion.base) { store.moveList(dragged, to: list.id) }
                    return true
                } isTargeted: { isTargeted in
                    dropTarget = isTargeted ? list.id : dropTarget == list.id ? nil : dropTarget
                }
                .overlay {
                    if dropTarget == list.id {
                        RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Palette.lime.opacity(0.5))
                    }
                }
            }

            Spacer(minLength: Space.s4)

            FocusedTodayCard(store: store)
                .padding(.horizontal, 2)
                .padding(.bottom, 10)

            NavRow(
                title: "Trash", symbol: "trash", count: store.trashItems.isEmpty ? nil : store.trashItems.count,
                isSelected: store.page == .trash, height: 32
            ) {
                store.inspect(nil)
                store.page = .trash
            }
            NavRow(title: "Settings", symbol: "gearshape", shortcut: "⌘,", isSelected: false, height: 32) {
                store.showSettings()
            }
        }
        .padding(.top, 52)
        .padding(.horizontal, Space.s3)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            LinearGradient(colors: [Palette.cardTop.opacity(0.9), Palette.panel], startPoint: .top, endPoint: .bottom)
                .overlay(alignment: .trailing) { Rectangle().fill(Color.white.opacity(0.06)).frame(width: 1) }
                .ignoresSafeArea()
        }
    }

    /// DESIGN_SYSTEM §12: Rename · Color & Icon · Archive · Delete. The last list stays, since tasks need one.
    @ViewBuilder
    private func listMenu(_ list: TaskList) -> some View {
        Button("Rename", systemImage: "pencil") { store.listSheet = .edit(list.id) }
        Button("Color & Icon", systemImage: "paintpalette") { store.listSheet = .edit(list.id) }
        Divider()
        Button("Archive", systemImage: "archivebox") { store.archiveList(list.id) }
            .disabled(!store.canRemoveLists)
        Button("Delete", systemImage: "trash", role: .destructive) { store.listSheet = .delete(list.id) }
            .disabled(!store.canRemoveLists)
    }

    private var brand: some View {
        HStack(spacing: 10) {
            KomodoMark(size: 30)
                .shadow(color: Palette.lime.opacity(0.5), radius: 9, y: 6)
            Text("Komodo")
                .font(.system(size: 15.5, weight: .bold))
                .tracking(-0.15)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize()
            Spacer(minLength: 0)
            Label("On this Mac", systemImage: "lock.shield")
                .font(.system(size: 10.5, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(Palette.greenText)
                // Wraps to two lines in the narrow sidebar, as on the canvas, rather than truncating.
                .lineLimit(2)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Palette.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.horizontal, Space.s2)
        .padding(.top, 2)
        .padding(.bottom, 18)
    }
}

private struct NavRow: View {
    var title: String
    var symbol: String
    var shortcut: String?
    var count: Int?
    var isSelected: Bool
    var height: CGFloat = 34
    var action: () -> Void

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                Text(title).frame(maxWidth: .infinity, alignment: .leading)
                if let shortcut { KeyCap(shortcut) }
                if let count {
                    Text("\(count)").font(.system(size: 11.5).monospacedDigit()).foregroundStyle(Palette.textMuted)
                }
            }
            .font(.system(size: height > 32 ? 13.5 : 13, weight: .medium))
            .foregroundStyle(isSelected || isHovered ? Palette.textPrimary : Palette.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: height)
            .background(
                Color.white.opacity(isSelected ? 0.08 : isHovered ? 0.06 : 0),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.55)
        .onHover { isHovered = $0 && isEnabled }
    }
}

private struct ListRow: View {
    var list: TaskList
    var count: Int
    var isSelected: Bool
    var action: () -> Void

    @State private var isHovered = false

    private var color: ListColor { ListColor(rawValue: list.color) ?? .lime }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ListBadge(letter: list.letter, color: color)
                    .shadow(color: isSelected ? color.fill.opacity(0.8) : .clear, radius: 7)
                Text(list.name)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(isSelected ? Palette.textPrimary : Palette.textBody)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(count)")
                    .font(.system(size: 11.5).monospacedDigit())
                    .foregroundStyle(Palette.textMuted)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 1).fill(Palette.lime).frame(width: 2).padding(.vertical, 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(list.name), \(count) open")
    }

    private var background: Color {
        if isSelected { return Palette.lime.opacity(0.07) }
        return Color.white.opacity(isHovered ? 0.06 : 0)
    }
}

/// Focused today, the last seven days as bars (today lit), and the streak.
private struct FocusedTodayCard: View {
    var store: BoardStore

    var body: some View {
        let now = store.now
        let days = (0..<7).map { store.today.adding(days: $0 - 6, calendar: store.calendar) }
        let daily = FocusHistory.daily(store.tasks, days: days, now: now, calendar: store.calendar)
        let focused = daily.last ?? 0
        let plan = store.dayPlan()
        let goal = focused + plan.estimateLeft
        let streak = store.streak
        let peak = max(daily.max() ?? 1, 1)

        VStack(alignment: .leading, spacing: Space.s3) {
            HStack(spacing: Space.s3) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: goal > 0 ? focused / goal : 0)
                        .stroke(
                            LinearGradient(
                                colors: [Palette.teal, Palette.lime], startPoint: .topLeading,
                                endPoint: .bottomTrailing),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 38, height: 38)
                .padding(4)
                VStack(alignment: .leading, spacing: 2) {
                    Text("FOCUSED TODAY")
                        .font(.system(size: 10.5, weight: .bold))
                        .tracking(0.84)
                        .foregroundStyle(Palette.textMuted)
                    Text(DurationFormat.short(focused))
                        .font(.system(size: 19, weight: .bold).monospacedDigit())
                        .tracking(-0.38)
                        .foregroundStyle(Palette.textPrimary)
                }
            }
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(daily.enumerated()), id: \.offset) { index, seconds in
                    let isToday = index == daily.count - 1
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(isToday ? AnyShapeStyle(todayBar) : AnyShapeStyle(Color.white.opacity(0.12)))
                        .frame(height: max(4, 30 * seconds / peak))
                        .shadow(color: isToday ? Palette.lime.opacity(0.5) : .clear, radius: 5)
                }
            }
            .frame(height: 30, alignment: .bottom)
            if streak > 1 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").font(.system(size: 11)).foregroundStyle(Palette.amber)
                    (Text("\(streak)-day").bold().foregroundColor(Palette.textPrimary) + Text(" streak"))
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textTertiary)
                }
            }
        }
        .padding(14)
        .spotlight(SpotlightTint.info, lifts: false) {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Palette.teal.opacity(0.1), location: 0),
                            .init(color: Color.white.opacity(0.025), location: 0.55),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(Palette.border, lineWidth: 1))
        }
    }

    private var todayBar: LinearGradient {
        LinearGradient(colors: [Palette.lime, Palette.teal], startPoint: .top, endPoint: .bottom)
    }
}

#Preview("Sidebar") {
    SidebarView(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment))
        .frame(width: Layout.sidebarIdeal, height: 900)
        .background(Palette.bg)
}
