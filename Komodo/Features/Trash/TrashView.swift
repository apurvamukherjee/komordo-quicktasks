import KomodoCore
import SwiftUI

/// Trash (DESIGN_SYSTEM §13.14, Trash.png): deleted tasks for 30 days, newest first, each with Restore and
/// Delete now on hover or right-click. Items with three days or fewer left say so in amber.
struct TrashView: View {
    @Bindable var store: BoardStore

    @State private var isConfirmingEmpty = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: Space.s1) {
                    Text("Trash")
                        .font(.system(size: 26, weight: .heavy))
                        .tracking(-0.8)
                        .foregroundStyle(Palette.textPrimary)
                    Text("Items are deleted after 30 days")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Button {
                    isConfirmingEmpty = true
                } label: {
                    Label("Empty Trash", systemImage: "trash")
                }
                .buttonStyle(KomodoButtonStyle(kind: .dangerOutline))
                .disabled(store.trash.isEmpty)
            }
            if store.trash.isEmpty {
                empty
            } else {
                table
            }
        }
        .padding(.top, 26)
        .padding(.horizontal, Space.s6)
        .padding(.bottom, Space.s5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.bg)
        .confirmationDialog(
            "Delete \(store.trash.count == 1 ? "this item" : "all \(store.trash.count) items") for good?",
            isPresented: $isConfirmingEmpty
        ) {
            Button("Empty Trash", role: .destructive, action: store.emptyTrash)
        } message: {
            Text("This can't be undone.")
        }
    }

    private var table: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        return VStack(spacing: 0) {
            TrashColumns(
                item: header("ITEM"), type: header("TYPE"), list: header("FROM LIST"), deleted: header("DELETED"),
                actions: Color.clear.frame(height: 1)
            )
            .frame(height: 36)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.trash) { task in
                        TrashRow(store: store, task: task)
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .padding(6)
        .frame(maxHeight: .infinity, alignment: .top)
        .spotlight(Palette.violet, radius: Radius.card, lifts: false) {
            shape.fill(Color.white.opacity(0.02)).overlay(shape.strokeBorder(Color.white.opacity(0.06)))
        }
    }

    private var empty: some View {
        VStack(spacing: Space.s3) {
            Image(systemName: "trash")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Palette.violetText)
                .frame(width: 76, height: 76)
                .background(
                    RadialGradient(
                        colors: [Palette.violet.opacity(0.22), Palette.violet.opacity(0.05)], center: .center,
                        startRadius: 0, endRadius: 38),
                    in: Circle()
                )
                .overlay(Circle().strokeBorder(Palette.violet.opacity(0.3)))
            Text("Trash is empty.")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            Text("Deleted lists and tasks wait here for 30 days.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10.5, weight: .bold))
            .tracking(Typography.Tracking.label)
            .foregroundStyle(Palette.textMuted)
    }
}

/// `.tr-grid`: the item takes what's left beside 110, 150, 170 and 200 pt columns.
private struct TrashColumns<Item: View, Kind: View, List: View, Deleted: View, Actions: View>: View {
    var item: Item
    var type: Kind
    var list: List
    var deleted: Deleted
    var actions: Actions

    var body: some View {
        HStack(spacing: Space.s3) {
            item.frame(maxWidth: .infinity, alignment: .leading)
            type.frame(width: 110, alignment: .leading)
            list.frame(width: 150, alignment: .leading)
            deleted.frame(width: 170, alignment: .leading)
            actions.frame(width: 200, alignment: .trailing)
        }
        .padding(.horizontal, Space.s4)
    }
}

private struct TrashRow: View {
    var store: BoardStore
    var task: TaskItem

    @State private var isHovered = false

    var body: some View {
        let list = store.lists.first { $0.id == task.listID }
        let color = list.flatMap { ListColor(rawValue: $0.color) } ?? .lime
        let left = task.deletedAt.map { Trash.daysLeft(deletedAt: $0, now: store.now, calendar: store.calendar) } ?? 0
        TrashColumns(
            item: HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                Text(task.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
            },
            type: Chip("Task", size: .compact),
            list: HStack(spacing: Space.s2) {
                if let list {
                    ListBadge(letter: list.letter, color: color, side: 18)
                    Text(list.name).font(.system(size: 12.5)).foregroundStyle(Palette.textBody).lineLimit(1)
                }
            },
            deleted: VStack(alignment: .leading, spacing: 1) {
                Text(deletedLabel).font(.system(size: 12.5)).foregroundStyle(Palette.textBody)
                Text(left == 1 ? "1 day left" : "\(left) days left")
                    .font(.system(size: 11, weight: left <= 3 ? .bold : .regular))
                    .foregroundStyle(left <= 3 ? Palette.amberText : Palette.textMuted)
            },
            actions: HStack(spacing: 6) {
                Button("Restore") { store.restore(task.id) }
                    .buttonStyle(KomodoButtonStyle(kind: .secondary, size: .small))
                Button("Delete now") { store.deleteForever(task.id) }
                    .buttonStyle(KomodoButtonStyle(kind: .dangerOutline, size: .small))
            }
            .opacity(isHovered ? 1 : 0)
        )
        .frame(height: 52)
        .background(
            Color.white.opacity(isHovered ? 0.04 : 0), in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(Motion.fast, value: isHovered)
        .contextMenu {
            Button("Restore", systemImage: "arrow.uturn.backward") { store.restore(task.id) }
            Button("Delete now", systemImage: "trash", role: .destructive) { store.deleteForever(task.id) }
        }
        .accessibilityElement(children: .contain)
    }

    /// "Today, 11:02 AM" for today, otherwise "Sep 24".
    private var deletedLabel: String {
        guard let date = task.deletedAt else { return "" }
        if store.calendar.isDate(date, inSameDayAs: store.now) {
            return "Today, " + date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

#Preview("Trash") {
    let store = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)
    for id in store.tasks.prefix(4).map(\.id) { store.delete(id) }
    return TrashView(store: store).frame(width: 1100, height: 700)
}

#Preview("Trash · empty") {
    TrashView(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)).frame(width: 1100, height: 500)
}
