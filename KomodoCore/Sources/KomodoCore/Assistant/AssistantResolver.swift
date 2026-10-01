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

    /// - Parameter request: what the user wrote. A change to a task their words don't name is dropped, since a
    ///   small model sometimes rewrites unrelated tasks instead of adding new ones.
    public static func resolve(_ plan: AssistantPlan, for request: String, in context: AssistantContext) -> Result {
        let words = request.lowercased()
        let grounds = Grounds(words)
        let phrases = RequestPhrase.split(request)
        /// A task's day, time and length come from its own phrase when one names it, since models mix them up
        /// between tasks; otherwise the model's, when the request supports them at all.
        func values(for name: String, day: String?, time: String?, minutes: Int?) -> RequestPhrase {
            if let phrase = RequestPhrase.best(for: name, in: phrases) { return phrase }
            var guess = RequestPhrase("")
            guess.day = day.flatMap { !$0.isEmpty && grounds.mentionsDay ? $0 : nil }
            guess.minute = time.flatMap(DayPhrase.minute).flatMap { grounds.allows(minute: $0) ? $0 : nil }
            guess.minutes = minutes.flatMap { $0 > 0 && grounds.mentionsDuration ? $0 : nil }
            return guess
        }
        func listName(_ name: String?) -> String? {
            guard let name, words.contains(name.lowercased()) else { return nil }
            return name
        }
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
                let listID = list(named: listName(item.list), in: context)?.id ?? context.defaultListID
                    ?? context.lists.first?.id
            else { continue }
            let said = values(
                for: parsed.title, day: item.day, time: item.time,
                minutes: item.estimateMinutes ?? parsed.estimate.map { Int($0 / 60) })
            var task = TaskItem(
                id: UUID().uuidString, listID: listID, title: parsed.title, bucket: .today, rank: 0,
                estimate: said.minutes.flatMap { $0 > 0 ? TimeInterval($0 * 60) : nil },
                notes: item.notes.flatMap { $0.isEmpty ? nil : $0 }, createdAt: context.now)
            task.subtasks = (item.subtasks ?? []).filter { !$0.isEmpty }.map {
                Subtask(id: UUID().uuidString, title: $0)
            }
            if let phrase = said.day {
                if let day = DayPhrase.day(phrase, today: context.today, calendar: context.calendar) {
                    task.scheduledDate = day
                } else {
                    problems.append("Didn't understand “\(phrase)” for \(parsed.title), so it's for today.")
                }
            }
            if let minute = said.minute {
                task.scheduledDate = task.scheduledDate ?? context.today
                task.scheduledMinute = minute
            }
            task.rank = rank(in: task.column(in: context.week))
            proposals.append(AssistantProposal(kind: .add, task: task))
        }

        for edit in plan.edit {
            let name = edit.task.trimmingCharacters(in: CharacterSet(charactersIn: "@ ")).lowercased()
            guard !name.isEmpty, words.contains(name) else { continue }
            guard let before = task(named: edit.task, in: context.tasks) else {
                problems.append("Couldn't find @\(edit.task.trimmingCharacters(in: CharacterSet(charactersIn: "@ "))).")
                continue
            }
            var task = proposals.first { $0.id == before.id }?.task ?? before
            // An edit only moves or times its task when the model meant to; the phrase supplies the value.
            let said = values(
                for: name, day: edit.day, time: edit.time, minutes: edit.logMinutes ?? edit.estimateMinutes)
            if let title = edit.title, !title.isEmpty { task.title = title }
            if let name = listName(edit.list) {
                if let list = list(named: name, in: context) {
                    task.listID = list.id
                } else {
                    problems.append("There's no list called “\(name)”.")
                }
            }
            if edit.day?.isEmpty == false, let phrase = said.day {
                if let day = DayPhrase.day(phrase, today: context.today, calendar: context.calendar) {
                    task.scheduledDate = day
                } else {
                    problems.append("Didn't understand “\(phrase)” for \(task.title).")
                }
            }
            if edit.time?.isEmpty == false, let minute = said.minute {
                task.scheduledDate = task.scheduledDate ?? context.today
                task.scheduledMinute = minute
            }
            if let column = edit.column.flatMap(Bucket.init(rawValue:)), column != task.column(in: context.week) {
                // As dragging does: a column move drops the date.
                task.bucket = column
                task.scheduledDate = nil
                task.scheduledMinute = nil
            }
            if edit.estimateMinutes != nil, edit.logMinutes == nil, let minutes = said.minutes {
                task.estimate = TimeInterval(minutes * 60)
            }
            if let notes = edit.notes, !notes.isEmpty {
                task.notes = [task.notes, notes].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n")
                task.notesRTF = nil
            }
            task.subtasks += (edit.addSubtasks ?? []).filter { !$0.isEmpty }.map {
                Subtask(id: UUID().uuidString, title: $0)
            }
            var logged: Int?
            if edit.logMinutes != nil, let minutes = said.minutes {
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
        // A brain dump never loses an item: a phrase no proposal or change covers becomes a task of its own.
        if !plan.add.isEmpty, let listID = context.defaultListID ?? context.lists.first?.id {
            let covered = Set(
                proposals.compactMap { RequestPhrase.best(for: $0.task.title, in: phrases)?.text }
                    + plan.edit.compactMap { RequestPhrase.best(for: $0.task, in: phrases)?.text })
            for phrase in phrases where !covered.contains(phrase.text) && !phrase.text.contains("@") {
                let title = phrase.title
                guard !title.isEmpty else { continue }
                var task = TaskItem(
                    id: UUID().uuidString, listID: listID, title: title, bucket: .today, rank: 0,
                    estimate: phrase.minutes.map { TimeInterval($0 * 60) }, createdAt: context.now)
                if let day = phrase.day.flatMap({ DayPhrase.day($0, today: context.today, calendar: context.calendar) })
                {
                    task.scheduledDate = day
                }
                if let minute = phrase.minute {
                    task.scheduledDate = task.scheduledDate ?? context.today
                    task.scheduledMinute = minute
                }
                task.rank = rank(in: task.column(in: context.week))
                proposals.append(AssistantProposal(kind: .add, task: task))
            }
        }
        return Result(proposals: proposals, problems: problems)
    }

    /// What the user's own words support. Small models invent times, lengths, days and lists; a value is kept only
    /// when the request gives something for it: the hour among its numbers, any duration, any day, the list's name.
    struct Grounds {
        let numbers: Set<Int>
        let mentionsDuration: Bool
        let mentionsDay: Bool
        let saysNoon: Bool
        let saysMidnight: Bool

        init(_ words: String) {
            numbers = Set(words.split { !$0.isNumber }.compactMap { Int($0) })
            mentionsDuration =
                words.range(
                    of: #"\d+(\.\d+)?\s*(h|hr|hrs|hour|hours|m|min|mins|minute|minutes)\b"#, options: .regularExpression
                )
                != nil
            let dayWords = [
                "today", "tonight", "tomorrow", "tmrw", "next week", "mon", "tue", "wed", "thu", "fri", "sat", "sun",
                "in ",
            ]
            mentionsDay =
                dayWords.contains { words.contains($0) }
                || words.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil
            saysNoon = words.contains("noon")
            saysMidnight = words.contains("midnight")
        }

        func allows(minute: Int) -> Bool {
            let hour = minute / 60
            if minute == 0 { return saysMidnight || numbers.contains(12) || numbers.contains(0) }
            if minute == 12 * 60, saysNoon { return true }
            return numbers.contains(hour) || numbers.contains(hour % 12 == 0 ? 12 : hour % 12)
        }
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
