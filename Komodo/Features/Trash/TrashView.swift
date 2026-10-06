import KomodoCore
import SwiftUI

/// Trash (DESIGN_SYSTEM §13.14, Trash.png): deleted lists and tasks for 30 days, newest first, each with Restore
/// and Delete now on hover or right-click. Items with three days or fewer left say so in amber.
/// The Archive reuses the same table for archived lists and tasks, with Restore and Move to Trash; no canvas draws it.
struct TrashView: View {
    enum Shelf {
        case trash
        case archive
    }

    @Bindable var store: BoardStore
    var shelf = Shelf.trash

    @State private var isConfirmingEmpty = false

    private var items: [BoardStore.TrashItem] { shelf == .trash ? store.trashItems : store.archiveItems }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: Space.s1) {
                    Text(shelf == .trash ? "Trash" : "Archive")
                        .font(.system(size: 26, weight: .heavy))
                        .tracking(-0.8)
                        .foregroundStyle(Palette.textPrimary)
                    Text(shelf == .trash ? "Items are deleted after 30 days" : "Archived items still count in Reports")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                if shelf == .trash {
                    Button {
                        isConfirmingEmpty = true
                    } label: {
                        Label("Empty Trash", systemImage: "trash")
                    }
                    .buttonStyle(KomodoButtonStyle(kind: .dangerOutline))
                    .disabled(items.isEmpty)
                }
            }
            if items.isEmpty {
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
            "Delete \(itemCount == 1 ? "this item" : "all \(itemCount) items") for good?",
            isPresented: $isConfirmingEmpty
        ) {
            Button("Empty Trash", role: .destructive, action: store.emptyTrash)
        } message: {
            Text("This can't be undone.")
        }
    }

    private var itemCount: Int { items.count }

    private var table: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        return VStack(spacing: 0) {
            TrashColumns(
                item: header("ITEM"), type: header("TYPE"), list: header("FROM LIST"),
                deleted: header(shelf == .trash ? "DELETED" : "ARCHIVED"),
                actions: Color.clear.frame(height: 1)
            )
            .frame(height: 36)
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        TrashRow(store: store, item: item, shelf: shelf)
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
            Image(systemName: shelf == .trash ? "trash" : "archivebox")
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
            Text(shelf == .trash ? "Trash is empty." : "Nothing archived.")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            Text(
                shelf == .trash
                    ? "Deleted lists and tasks wait here for 30 days."
                    : "Archive a list or task to keep it for Reports, off the Board."
            )
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
    var item: BoardStore.TrashItem
    var shelf: TrashView.Shelf

    @State private var isHovered = false

    var body: some View {
        let left = Trash.daysLeft(deletedAt: item.deletedAt, now: store.now, calendar: store.calendar)
        TrashColumns(
            item: HStack(spacing: 10) {
                switch item {
                case .list(let list):
                    ListBadge(letter: list.letter, color: color(of: list))
                case .task(let task) where task.completedAt != nil:
                    // The Board's done mark, since most archived tasks are finished ones kept for Reports.
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(Palette.onAccent)
                        .frame(width: 18, height: 18)
                        .background(Palette.green, in: Circle())
                        .accessibilityLabel("Done")
                case .task:
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 18, height: 18)
                }
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
            },
            type: isList ? Chip("List", tint: .violet, size: .compact) : Chip("Task", size: .compact),
            list: HStack(spacing: Space.s2) {
                if let list = fromList {
                    ListBadge(letter: list.letter, color: color(of: list), side: 18)
                    Text(list.name).font(.system(size: 12.5)).foregroundStyle(Palette.textBody).lineLimit(1)
                }
            },
            deleted: VStack(alignment: .leading, spacing: 1) {
                Text(dateLabel).font(.system(size: 12.5)).foregroundStyle(Palette.textBody)
                if shelf == .trash {
                    Text(left == 1 ? "1 day left" : "\(left) days left")
                        .font(.system(size: 11, weight: left <= 3 ? .bold : .regular))
                        .foregroundStyle(left <= 3 ? Palette.amberText : Palette.textMuted)
                }
            },
            actions: HStack(spacing: 6) {
                Button("Restore", action: restore)
                    .buttonStyle(KomodoButtonStyle(kind: .secondary, size: .small))
                Button(removeTitle, action: remove)
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
            Button("Restore", systemImage: "arrow.uturn.backward", action: restore)
            Button(removeTitle, systemImage: "trash", role: .destructive, action: remove)
        }
        .accessibilityElement(children: .contain)
    }

    private var isList: Bool {
        if case .list = item { return true }
        return false
    }

    private var title: String {
        switch item {
        case .task(let task): task.title
        case .list(let list): list.name
        }
    }

    /// A list comes from itself, as on the canvas.
    private var fromList: TaskList? {
        switch item {
        case .task(let task): store.list(for: task)
        case .list(let list): list
        }
    }

    private func color(of list: TaskList) -> ListColor { ListColor(rawValue: list.color) ?? .lime }

    private var removeTitle: String { shelf == .trash ? "Delete now" : "Move to Trash" }

    private func restore() {
        switch (item, shelf) {
        case (.task(let task), .trash): store.restore(task.id)
        case (.list(let list), .trash): store.restoreList(list.id)
        case (.task(let task), .archive): store.unarchive(task.id)
        case (.list(let list), .archive): store.unarchiveList(list.id)
        }
    }

    private func remove() {
        switch (item, shelf) {
        case (.task(let task), .trash): store.deleteForever(task.id)
        case (.list(let list), .trash): store.deleteListForever(list.id)
        case (.task(let task), .archive): store.trashArchived(task.id)
        case (.list(let list), .archive): store.trashArchivedList(list.id)
        }
    }

    /// "Today, 11:02 AM" for today, otherwise "Sep 24".
    private var dateLabel: String {
        let date = shelf == .trash ? item.deletedAt : item.archivedAt
        if store.calendar.isDate(date, inSameDayAs: store.now) {
            return "Today, " + date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

#Preview("Trash") {
    let store = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)
    for id in store.tasks.prefix(4).map(\.id) { store.delete(id) }
    store.deleteList("growth")
    return TrashView(store: store).frame(width: 1100, height: 700)
}

#Preview("Archive") {
    let store = BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)
    store.archiveList("growth")
    return TrashView(store: store, shelf: .archive).frame(width: 1100, height: 700)
}

#Preview("Trash · empty") {
    TrashView(store: BoardSamples.store(anchoredAt: BoardSamples.artboardMoment)).frame(width: 1100, height: 500)
}
