import Foundation

/// A task tool connected with a personal token (FEATURES §5, ARCHITECTURE §8).
public enum Provider: String, CaseIterable, Identifiable, Sendable {
    case todoist
    case notion
    case linear
    case clickup
    case asana

    public var id: Self { self }

    public var source: TaskSource {
        switch self {
        case .todoist: .todoist
        case .notion: .notion
        case .linear: .linear
        case .clickup: .clickup
        case .asana: .asana
        }
    }

    /// Linear only imports (FEATURES §5); the rest sync both ways.
    public var isTwoWay: Bool { self != .linear }

    /// Providers with both a start and a due date let the user pick which one schedules the task.
    public var hasDateMapping: Bool { self == .notion || self == .clickup || self == .asana }

    /// Providers whose items have statuses, rather than only open and done.
    public var hasStatusMapping: Bool { self == .notion || self == .linear || self == .clickup }

    /// What each keeps of a task. Linear, Notion and Asana have no time estimate to map to, Notion keeps notes in
    /// the page body rather than a property, and Linear has no planned date; its due date is the schedule.
    /// Notion's checkbox properties and Asana's subtasks are subtasks. When the due date schedules a task,
    /// Komodo's own due date has nothing to sync with.
    public func shape(_ mapping: DateMapping) -> ExternalItem.Shape {
        var fields: Set<ExternalItem.Field> = [.title, .notes, .date, .minute, .dueDate, .estimate, .done]
        switch self {
        case .todoist: return .todoist
        case .notion: fields.subtract([.notes, .estimate])
        case .linear: fields.subtract([.minute, .dueDate, .estimate])
        case .asana: fields.subtract([.estimate])
        case .clickup: break
        }
        if hasDateMapping, mapping == .due { fields.remove(.dueDate) }
        if hasStatusMapping { fields.insert(.column) }
        if self == .notion || self == .asana { fields.insert(.subtasks) }
        return ExternalItem.Shape(fields: fields)
    }
}

/// Which provider date becomes the task's schedule (FEATURES §5 "Date mapping"). With `start`, the due date stays
/// Komodo's due date; with `due`, it schedules the task and the start date isn't read.
public enum DateMapping: String, CaseIterable, Sendable {
    case start
    case due
}

/// A provider status, grouped the way every provider groups its own.
public struct ProviderStatus: Equatable, Hashable, Sendable {
    public enum Kind: String, Sendable {
        /// Not started: to do, backlog, open.
        case todo
        case active
        /// Finished, cancelled included.
        case done
    }

    public var name: String
    public var kind: Kind

    public init(name: String, kind: Kind) {
        self.name = name
        self.kind = kind
    }
}

/// Where an item in a status goes (FEATURES §5 "Status mapping"). A dated item is placed by its date whatever
/// the status, so a column only decides where an undated one goes.
public enum StatusTarget: String, CaseIterable, Sendable {
    case byDate
    case backlog
    case week
    case today
    case done

    public var bucket: Bucket? {
        switch self {
        case .byDate, .done: nil
        case .backlog: .backlog
        case .week: .week
        case .today: .today
        }
    }
}

/// One provider's connection to one list, kept in preferences; the token is in the Keychain, never here.
public struct ProviderConnection: Equatable, Sendable {
    /// The project, database, team or list synced with a list; nil while the provider isn't connected.
    public var sourceID: String?
    public var sourceName = ""
    /// The list the source syncs with; nil means the first list.
    public var listID: String?
    public var autoSync = true
    public var syncsDeletes = false
    public var onlyMine = false
    /// Where the last pull left off; nil asks for everything.
    public var cursor: String?
    /// The account's own ID, for "Only my items".
    public var userID: String?
    /// Tasks made in the list before this stay in Komodo.
    public var connectedAt: Date?
    public var lastSync: Date?
    /// Why the last sync failed, or what the provider refused, until a sync goes through cleanly.
    public var problem: String?
    public var dateMapping = DateMapping.due
    /// The source's statuses as the last sync read them, in the provider's order.
    public var statuses: [ProviderStatus] = []
    /// The user's choices by status name; a status with none goes where its kind suggests.
    public var statusTargets: [String: StatusTarget] = [:]

    public init() {}

    public var isConnected: Bool { sourceID != nil }

    public func target(for status: ProviderStatus) -> StatusTarget {
        if let target = statusTargets[status.name] { return target }
        switch status.kind {
        case .todo: return .byDate
        case .active: return .today
        case .done: return .done
        }
    }

    /// The status to send for a task in `bucket`, or finished: the first status whose target matches, then the
    /// first that leaves it to the date. Nil when none fits, so the provider's status is left alone.
    public func status(for bucket: Bucket, isDone: Bool) -> ProviderStatus? {
        if isDone { return statuses.first { target(for: $0) == .done } }
        return statuses.first { target(for: $0).bucket == bucket }
            ?? statuses.first { target(for: $0) == .byDate }
    }

    // MARK: Storage

    private enum Key: String, CaseIterable {
        case source = "ProjectID"
        case sourceName = "ProjectName"
        case list = "ListID"
        case autoSync = "AutoSync"
        case deletes = "SyncsDeletes"
        case onlyMine = "OnlyMine"
        case cursor = "SyncToken"
        case user = "UserID"
        case connected = "ConnectedAt"
        case lastSync = "LastSync"
        case problem = "Problem"
        case dateMapping = "DateMapping"
        case statuses = "Statuses"
        case statusTargets = "StatusTargets"
    }

    /// Todoist's keys from before there were other providers (`todoistProjectID` …) are the same names, so a
    /// connection made then carries over; only its last sync time had another name.
    init(stored: [String: String], provider: Provider) {
        func value(_ key: Key) -> String? {
            let text =
                stored[provider.rawValue + key.rawValue]
                ?? (key == .lastSync && provider == .todoist ? stored["lastTodoistSync"] : nil)
            return text.flatMap { $0.isEmpty ? nil : $0 }
        }
        func date(_ key: Key) -> Date? { value(key).flatMap(Double.init).map(Date.init(timeIntervalSince1970:)) }
        sourceID = value(.source)
        sourceName = value(.sourceName) ?? ""
        listID = value(.list)
        if let text = value(.autoSync) { autoSync = text == "1" }
        if let text = value(.deletes) { syncsDeletes = text == "1" }
        if let text = value(.onlyMine) { onlyMine = text == "1" }
        cursor = value(.cursor)
        userID = value(.user)
        connectedAt = date(.connected)
        lastSync = date(.lastSync)
        problem = value(.problem)
        if let mapping = value(.dateMapping).flatMap(DateMapping.init) { dateMapping = mapping }
        statuses = (value(.statuses) ?? "").split(separator: "\n").compactMap { line in
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2, let kind = ProviderStatus.Kind(rawValue: String(parts[0])) else { return nil }
            return ProviderStatus(name: String(parts[1]), kind: kind)
        }
        for line in (value(.statusTargets) ?? "").split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1)
            if parts.count == 2, let target = StatusTarget(rawValue: String(parts[0])) {
                statusTargets[String(parts[1])] = target
            }
        }
    }

    func stored(for provider: Provider) -> [String: String] {
        func flag(_ value: Bool) -> String { value ? "1" : "0" }
        func time(_ date: Date?) -> String { date.map { String($0.timeIntervalSince1970) } ?? "" }
        let values: [Key: String] = [
            .source: sourceID ?? "", .sourceName: sourceName, .list: listID ?? "", .autoSync: flag(autoSync),
            .deletes: flag(syncsDeletes), .onlyMine: flag(onlyMine), .cursor: cursor ?? "", .user: userID ?? "",
            .connected: time(connectedAt), .lastSync: time(lastSync), .problem: problem ?? "",
            .dateMapping: dateMapping.rawValue,
            .statuses: statuses.map { "\($0.kind.rawValue)\t\($0.name)" }.joined(separator: "\n"),
            // Sorted, so an unchanged map stores the same string and writes nothing.
            .statusTargets: statusTargets.sorted { $0.key < $1.key }.map { "\($1.rawValue)\t\($0)" }
                .joined(separator: "\n"),
        ]
        return Dictionary(uniqueKeysWithValues: values.map { (provider.rawValue + $0.rawValue, $1) })
    }
}
