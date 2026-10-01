import Foundation

/// The board as the Assistant sees it: lists, open tasks and today.
public struct AssistantContext: Sendable {
    public var lists: [TaskList]
    public var tasks: [TaskItem]
    /// Where a new task goes when the plan names no list or one that doesn't exist.
    public var defaultListID: String?
    public var week: WeekRange
    public var now: Date
    public var calendar: Calendar

    public init(
        lists: [TaskList], tasks: [TaskItem], defaultListID: String?, week: WeekRange, now: Date, calendar: Calendar
    ) {
        self.lists = lists
        self.tasks = tasks
        self.defaultListID = defaultListID
        self.week = week
        self.now = now
        self.calendar = calendar
    }

    var today: LocalDate { week.today }
}

/// One row of the editable preview (DESIGN_SYSTEM §13.26): the task as it would be saved. Unticked rows and
/// edited titles are honored when the preview is applied.
public struct AssistantProposal: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case add
        /// A change to a task that exists; `before` is how it is now, for Undo and for the row's arrow.
        case edit(before: TaskItem)
    }

    public var id: String { task.id }
    public var kind: Kind
    public var task: TaskItem
    public var isIncluded = true
    /// Minutes logged by this change, shown on the row.
    public var loggedMinutes: Int?
}

/// Turns a plan into proposals against the board: names become IDs, words become dates, and new tasks are ranked
/// at the end of their column. Anything that can't be matched is reported instead of guessed.
public enum AssistantResolver {
    public struct Result: Equatable, Sendable {
        public var proposals: [AssistantProposal]
        /// "Couldn't find @Gym." and the like, shown under the reply.
        public var problems: [String]
    }

    public static func resolve(_ plan: AssistantPlan, in context: AssistantContext) -> Result {
        var proposals: [AssistantProposal] = []
        var problems: [String] = []
        var nextRank: [Bucket: Double] = [:]
        func rank(in column: Bucket) -> Double {
            let rank =
                nextRank[column]
                ?? (context.tasks.filter { $0.column(in: context.week) == column && !$0.isDone }.map(\.rank).max()
                    ?? 0) + 1
            nextRank[column] = rank + 1
            return rank
        }

        for item in plan.add {
            let parsed = EstimateParser.parse(item.title)
            guard !parsed.title.isEmpty,
                let listID = list(named: item.list, in: context)?.id ?? context.defaultListID ?? context.lists.first?.id
            else { continue }
            var task = TaskItem(
                id: UUID().uuidString, listID: listID, title: parsed.title, bucket: .today, rank: 0,
                estimate: item.estimateMinutes.map { TimeInterval(max(0, $0) * 60) } ?? parsed.estimate,
                notes: item.notes.flatMap { $0.isEmpty ? nil : $0 }, createdAt: context.now)
            task.subtasks = (item.subtasks ?? []).filter { !$0.isEmpty }.map {
                Subtask(id: UUID().uuidString, title: $0)
            }
            if let phrase = item.day, !phrase.isEmpty {
                if let day = DayPhrase.day(phrase, today: context.today, calendar: context.calendar) {
                    task.scheduledDate = day
                } else {
                    problems.append("Didn't understand “\(phrase)” for \(parsed.title), so it's for today.")
                }
            }
            if let phrase = item.time, !phrase.isEmpty, let minute = DayPhrase.minute(phrase) {
                task.scheduledDate = task.scheduledDate ?? context.today
                task.scheduledMinute = minute
            }
            task.rank = rank(in: task.column(in: context.week))
            proposals.append(AssistantProposal(kind: .add, task: task))
        }

        for edit in plan.edit {
            guard let before = task(named: edit.task, in: context.tasks) else {
                problems.append("Couldn't find @\(edit.task.trimmingCharacters(in: CharacterSet(charactersIn: "@ "))).")
                continue
            }
            var task = proposals.first { $0.id == before.id }?.task ?? before
            if let title = edit.title, !title.isEmpty { task.title = title }
            if let name = edit.list {
                if let list = list(named: name, in: context) {
                    task.listID = list.id
                } else {
                    problems.append("There's no list called “\(name)”.")
                }
            }
            if let phrase = edit.day, !phrase.isEmpty {
                if let day = DayPhrase.day(phrase, today: context.today, calendar: context.calendar) {
                    task.scheduledDate = day
                } else {
                    problems.append("Didn't understand “\(phrase)” for \(task.title).")
                }
            }
            if let phrase = edit.time, !phrase.isEmpty, let minute = DayPhrase.minute(phrase) {
                task.scheduledDate = task.scheduledDate ?? context.today
                task.scheduledMinute = minute
            }
            if let column = edit.column.flatMap(Bucket.init(rawValue:)), column != task.column(in: context.week) {
                // As dragging does: a column move drops the date.
                task.bucket = column
                task.scheduledDate = nil
                task.scheduledMinute = nil
            }
            if let minutes = edit.estimateMinutes { task.estimate = minutes > 0 ? TimeInterval(minutes * 60) : nil }
            if let notes = edit.notes, !notes.isEmpty {
                task.notes = [task.notes, notes].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
                task.notesRTF = nil
            }
            task.subtasks += (edit.addSubtasks ?? []).filter { !$0.isEmpty }.map {
                Subtask(id: UUID().uuidString, title: $0)
            }
            var logged: Int?
            if let minutes = edit.logMinutes, minutes > 0 {
                task.sessions.append(
                    WorkSession(start: context.now.addingTimeInterval(TimeInterval(-minutes * 60)), end: context.now))
                logged = minutes
            }
            if edit.done == true, !task.isDone { task.completedAt = context.now }
            if task.column(in: context.week) != before.column(in: context.week) {
                task.rank = rank(in: task.column(in: context.week))
            }
            guard task != before else { continue }
            task.editedAt = context.now
            proposals.removeAll { $0.id == task.id }
            proposals.append(AssistantProposal(kind: .edit(before: before), task: task, loggedMinutes: logged))
        }
        return Result(proposals: proposals, problems: problems)
    }

    /// Exact title first, then one that starts with the name, then one that contains it; open tasks before done.
    static func task(named raw: String, in tasks: [TaskItem]) -> TaskItem? {
        let name = raw.trimmingCharacters(in: CharacterSet(charactersIn: "@ ")).lowercased()
        guard !name.isEmpty else { return nil }
        let ordered = tasks.filter { !$0.isDone } + tasks.filter(\.isDone)
        return ordered.first { $0.id == raw }
            ?? ordered.first { $0.title.lowercased() == name }
            ?? ordered.first { $0.title.lowercased().hasPrefix(name) }
            ?? ordered.first { $0.title.lowercased().contains(name) }
    }

    private static func list(named name: String?, in context: AssistantContext) -> TaskList? {
        guard let name = name?.trimmingCharacters(in: .whitespaces).lowercased(), !name.isEmpty else { return nil }
        return context.lists.first { $0.name.lowercased() == name || $0.id == name }
    }
}
