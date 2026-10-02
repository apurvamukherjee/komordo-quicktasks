import Foundation

extension Todoist {
    /// One write in a sync request (`item_add`, `item_update`, `item_close` …).
    public struct Command: Encodable, Equatable, Sendable {
        public var type: String
        public var uuid: String
        /// A new item's stand-in ID until `temp_id_mapping` names the real one: the task's own ID.
        public var tempID: String?
        public var args: [String: JSONValue]

        enum CodingKeys: String, CodingKey {
            case type, uuid, args
            case tempID = "temp_id"
        }
    }

    /// Every push as commands, keeping which commands belong to which push so each gets one outcome.
    public struct Batch: Sendable {
        public var pushes: [ExternalSync.Push]
        public var commands: [Command]
        /// The `uuid`s of each push's commands, in push order. Empty when Todoist has nothing to store.
        var groups: [[String]]

        public init(_ pushes: [ExternalSync.Push], projectID: String, uuid: () -> String = { UUID().uuidString }) {
            self.pushes = pushes
            var commands: [Command] = []
            var groups: [[String]] = []
            for push in pushes {
                var group: [Command] = []
                switch push {
                case .add(let task):
                    var args = Self.fields(of: task, Set(ExternalItem.Field.allCases))
                    args["project_id"] = .string(projectID)
                    group.append(Command(type: "item_add", uuid: uuid(), tempID: task.id, args: args))
                case .update(let externalID, let task, let changes):
                    var args = Self.fields(of: task, changes)
                    if !args.isEmpty {
                        args["id"] = .string(externalID)
                        group.append(Command(type: "item_update", uuid: uuid(), args: args))
                    }
                    if changes.contains(.done) {
                        group.append(
                            Command(
                                type: task.isDone ? "item_close" : "item_uncomplete", uuid: uuid(),
                                args: ["id": .string(externalID)]))
                    }
                case .delete(let externalID):
                    group.append(Command(type: "item_delete", uuid: uuid(), args: ["id": .string(externalID)]))
                }
                commands += group
                groups.append(group.map(\.uuid))
            }
            self.commands = commands
            self.groups = groups
        }

        /// The item fields for the changed fields. A duration needs a due date at Todoist, so an estimate on an
        /// undated task stays in Komodo.
        static func fields(of task: TaskItem, _ changes: Set<ExternalItem.Field>) -> [String: JSONValue] {
            var args: [String: JSONValue] = [:]
            if changes.contains(.title) { args["content"] = .string(task.title) }
            if changes.contains(.notes) { args["description"] = .string(task.notes ?? "") }
            if !changes.isDisjoint(with: [.date, .minute]) {
                args["due"] =
                    task.scheduledDate.map { day in
                        let time = task.scheduledMinute.map { String(format: "T%02d:%02d:00", $0 / 60, $0 % 60) } ?? ""
                        return .object(["date": .string(day.description + time)])
                    } ?? .null
            }
            if changes.contains(.dueDate) {
                args["deadline"] = task.dueDate.map { .object(["date": .string($0.description)]) } ?? .null
            }
            if changes.contains(.estimate), task.scheduledDate != nil {
                args["duration"] =
                    task.estimate.map { estimate in
                        .object(["amount": .int(max(1, Int((estimate / 60).rounded()))), "unit": .string("minute")])
                    } ?? .null
            }
            return args
        }

        /// One outcome per push: refused if any of its commands was, with Todoist's reason.
        public func outcomes(_ response: SyncResponse) -> [ExternalSync.Outcome] {
            zip(pushes, groups).map { push, group in
                for id in group {
                    switch response.syncStatus[id] {
                    case .ok: continue
                    case .failed(let reason): return .refused(reason)
                    case nil: return .refused("Todoist didn't answer")
                    }
                }
                guard case .add(let task) = push else { return .accepted }
                guard let id = response.tempIDMapping[task.id] else { return .refused("Todoist didn't return an ID") }
                return .added(externalID: id, url: Todoist.taskURL(id))
            }
        }
    }
}
