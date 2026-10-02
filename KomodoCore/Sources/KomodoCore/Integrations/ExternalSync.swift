import Foundation

/// Two-way sync between one list and one provider project (FEATURES §5, ARCHITECTURE §8), as pure functions:
/// `pull` takes what the provider says changed, `pushes` says what Komodo changed, and `confirm` records what
/// the provider accepted. Links are only rewritten once both sides agree.
public enum ExternalSync {
    public struct Context: Sendable {
        public var connectionID: String
        public var source: TaskSource
        /// The list imported items join and new tasks are sent from.
        public var listID: String
        /// The project's name, shown as where a task came from.
        public var sourceTitle: String
        public var onlyMine: Bool
        public var syncsDeletes: Bool
        /// Tasks made in the list before connecting stay in Komodo.
        public var connectedAt: Date
        public var week: WeekRange
        public var now: Date

        public init(
            connectionID: String, source: TaskSource, listID: String, sourceTitle: String, onlyMine: Bool,
            syncsDeletes: Bool, connectedAt: Date, week: WeekRange, now: Date
        ) {
            self.connectionID = connectionID
            self.source = source
            self.listID = listID
            self.sourceTitle = sourceTitle
            self.onlyMine = onlyMine
            self.syncsDeletes = syncsDeletes
            self.connectedAt = connectedAt
            self.week = week
            self.now = now
        }

        /// Imported tasks take their item's ID, so a lost link or a restored backup can't import one twice.
        public func taskID(for externalID: String) -> String { "\(connectionID):\(externalID)" }
    }

    /// Applies the provider's changed items.
    ///
    /// - Parameters:
    ///   - board: open and done tasks on the Board.
    ///   - known: every task ID Komodo has, Trash and archive included, so those never come back.
    /// - Returns: the tasks to save and the connection's links afterwards.
    public static func pull(
        _ items: [ExternalItem], links: [ExternalLink], board: [TaskItem], known: Set<String>, context: Context
    ) -> (saved: [TaskItem], links: [ExternalLink]) {
        var links = links
        var saved: [TaskItem] = []
        var ends = ColumnEnd(board: board, week: context.week)
        let byID = Dictionary(board.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for item in items {
            if let index = links.firstIndex(where: { $0.externalID == item.id }) {
                let link = links[index]
                guard !item.isDeleted else {
                    // FEATURES §5: deleting at the provider only unlinks, keeping notes and sessions.
                    links.remove(at: index)
                    if var task = byID[link.taskID] {
                        task.source = nil
                        task.sourceTitle = nil
                        task.sourceURL = nil
                        saved.append(task)
                    }
                    continue
                }
                links[index].remoteUpdatedAt = item.updatedAt
                // In Trash or archived: left alone until it's back.
                guard var task = byID[link.taskID], item.snapshot != link.snapshot else { continue }
                let editedHere = ExternalItem.snapshot(of: task) != link.snapshot
                // Both sides changed: the newer edit wins. A task with no edit time loses, since a provider's
                // `updated_at` is always known.
                if editedHere, (item.updatedAt ?? .distantPast) <= (task.editedAt ?? .distantPast) { continue }
                apply(item, to: &task, now: context.now)
                saved.append(task)
                links[index].snapshot = item.snapshot
                continue
            }
            guard !item.isDeleted, !item.isDone, item.isMine || !context.onlyMine else { continue }
            let id = context.taskID(for: item.id)
            guard !known.contains(id) else { continue }
            var task = TaskItem(
                id: id, listID: context.listID, title: item.title, bucket: .backlog, rank: 0, createdAt: context.now)
            apply(item, to: &task, now: context.now)
            task.source = context.source
            task.sourceTitle = context.sourceTitle
            task.rank = ends.rank(for: task.column(in: context.week))
            saved.append(task)
            links.append(
                ExternalLink(
                    connectionID: context.connectionID, externalID: item.id, taskID: id,
                    remoteUpdatedAt: item.updatedAt, snapshot: item.snapshot))
        }
        return (saved, links)
    }

    /// One change for the provider.
    public enum Push: Equatable, Sendable {
        /// A task made in the list since connecting.
        case add(TaskItem)
        case update(externalID: String, task: TaskItem, changes: Set<ExternalItem.Field>)
        /// A linked task deleted here, with Sync deletes on.
        case delete(externalID: String)
    }

    /// What Komodo changed since the links were last agreed.
    ///
    /// - Parameters:
    ///   - board: open and done tasks on the Board.
    ///   - known: every task ID Komodo has; a linked task missing from it was deleted for good.
    ///   - trash: the IDs of tasks in Trash.
    public static func pushes(
        links: [ExternalLink], board: [TaskItem], known: Set<String>, trash: Set<String>, context: Context
    ) -> [Push] {
        let byID = Dictionary(board.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var pushes: [Push] = []
        for link in links {
            if let task = byID[link.taskID] {
                let changes = ExternalItem.changes(from: link.snapshot, to: ExternalItem.snapshot(of: task))
                if !changes.isEmpty {
                    pushes.append(.update(externalID: link.externalID, task: task, changes: changes))
                }
            } else if context.syncsDeletes, trash.contains(link.taskID) || !known.contains(link.taskID) {
                pushes.append(.delete(externalID: link.externalID))
            }
        }
        let linked = Set(links.map(\.taskID))
        // An imported task whose item was deleted keeps its ID, and must not go back as a new one. Repeating tasks
        // stay here, since every occurrence would become its own item.
        let prefix = context.taskID(for: "")
        for task in board
        where task.listID == context.listID && !linked.contains(task.id) && !task.id.hasPrefix(prefix)
            && task.source == nil && !task.isDone && task.repeatRule == nil && task.repeatParentID == nil
            && (task.createdAt ?? .distantPast) >= context.connectedAt
        {
            pushes.append(.add(task))
        }
        return pushes
    }

    private static func apply(_ item: ExternalItem, to task: inout TaskItem, now: Date) {
        task.title = item.title
        if (task.notes ?? "") != (item.notes ?? "") {
            task.notes = item.notes
            // The formatted copy would show the old text in the editor.
            task.notesRTF = nil
        }
        task.scheduledDate = item.date
        task.scheduledMinute = item.date == nil ? nil : item.minute
        task.dueDate = item.dueDate
        task.estimate = item.estimate
        if item.isDone != task.isDone { task.completedAt = item.isDone ? item.updatedAt ?? now : nil }
        task.sourceURL = item.url
    }
}
