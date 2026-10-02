import Foundation

/// Todoist's API v1 (developer.todoist.com/api/v1), as much of it as Komodo reads. Everything goes through the
/// one sync endpoint: a full read with `*`, then only what changed since the token it hands back, deletes and
/// completions included, which polling needs and the plain task list can't say.
public enum Todoist {
    public static let syncURL = URL(string: "https://api.todoist.com/api/v1/sync")
    public static let tokenHelpURL = URL(string: "https://todoist.com/help/articles/find-your-api-token-Jpzx9IIlB")

    public struct SyncResponse: Decodable, Sendable {
        public var syncToken: String
        public var fullSync: Bool
        public var items: [Item]
        public var projects: [Project]
        public var user: User?
        /// Each command's result by its `uuid`.
        public var syncStatus: [String: CommandStatus]
        /// Real IDs for the `temp_id`s of items Komodo added.
        public var tempIDMapping: [String: String]

        enum CodingKeys: String, CodingKey {
            case syncToken = "sync_token"
            case fullSync = "full_sync"
            case items, projects, user
            case syncStatus = "sync_status"
            case tempIDMapping = "temp_id_mapping"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            syncToken = try container.decode(String.self, forKey: .syncToken)
            fullSync = try container.decodeIfPresent(Bool.self, forKey: .fullSync) ?? false
            items = try container.decodeIfPresent([Item].self, forKey: .items) ?? []
            projects = try container.decodeIfPresent([Project].self, forKey: .projects) ?? []
            user = try container.decodeIfPresent(User.self, forKey: .user)
            syncStatus = try container.decodeIfPresent([String: CommandStatus].self, forKey: .syncStatus) ?? [:]
            tempIDMapping = try container.decodeIfPresent([String: String].self, forKey: .tempIDMapping) ?? [:]
        }
    }

    public struct Item: Decodable, Equatable, Sendable {
        public var id: String
        public var projectID: String
        public var content: String
        public var description: String
        public var due: Due?
        public var deadline: Deadline?
        public var duration: Duration?
        public var checked: Bool
        public var isDeleted: Bool
        /// Who it's assigned to in a shared project; nil when nobody is.
        public var responsibleUID: String?
        public var parentID: String?
        public var updatedAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case projectID = "project_id"
            case content, description, due, deadline, duration, checked
            case isDeleted = "is_deleted"
            case responsibleUID = "responsible_uid"
            case parentID = "parent_id"
            case updatedAt = "updated_at"
        }

        public init(
            id: String, projectID: String, content: String, description: String = "", due: Due? = nil,
            deadline: Deadline? = nil, duration: Duration? = nil, checked: Bool = false, isDeleted: Bool = false,
            responsibleUID: String? = nil, parentID: String? = nil, updatedAt: String? = nil
        ) {
            self.id = id
            self.projectID = projectID
            self.content = content
            self.description = description
            self.due = due
            self.deadline = deadline
            self.duration = duration
            self.checked = checked
            self.isDeleted = isDeleted
            self.responsibleUID = responsibleUID
            self.parentID = parentID
            self.updatedAt = updatedAt
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            projectID = try container.decode(String.self, forKey: .projectID)
            content = try container.decode(String.self, forKey: .content)
            description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
            due = try container.decodeIfPresent(Due.self, forKey: .due)
            deadline = try container.decodeIfPresent(Deadline.self, forKey: .deadline)
            duration = try container.decodeIfPresent(Duration.self, forKey: .duration)
            checked = try container.decodeIfPresent(Bool.self, forKey: .checked) ?? false
            isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
            responsibleUID = try container.decodeIfPresent(String.self, forKey: .responsibleUID)
            parentID = try container.decodeIfPresent(String.self, forKey: .parentID)
            updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        }
    }

    /// `date` is `2026-10-02` for a whole day, `2026-10-02T15:00:00` for a floating time, or ends in `Z` for a
    /// time fixed to a zone.
    public struct Due: Codable, Equatable, Sendable {
        public var date: String
        public var isRecurring: Bool

        enum CodingKeys: String, CodingKey {
            case date
            case isRecurring = "is_recurring"
        }

        public init(date: String, isRecurring: Bool = false) {
            self.date = date
            self.isRecurring = isRecurring
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            date = try container.decode(String.self, forKey: .date)
            isRecurring = try container.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? false
        }
    }

    public struct Deadline: Codable, Equatable, Sendable {
        public var date: String

        public init(date: String) { self.date = date }
    }

    public struct Duration: Codable, Equatable, Sendable {
        public var amount: Int
        /// `minute` or `day`.
        public var unit: String

        public init(amount: Int, unit: String) {
            self.amount = amount
            self.unit = unit
        }
    }

    public struct Project: Decodable, Equatable, Sendable {
        public var id: String
        public var name: String
        public var isDeleted: Bool
        public var isArchived: Bool

        enum CodingKeys: String, CodingKey {
            case id, name
            case isDeleted = "is_deleted"
            case isArchived = "is_archived"
        }

        public init(id: String, name: String, isDeleted: Bool = false, isArchived: Bool = false) {
            self.id = id
            self.name = name
            self.isDeleted = isDeleted
            self.isArchived = isArchived
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
            isArchived = try container.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        }
    }

    public struct User: Decodable, Equatable, Sendable {
        public var id: String
        public var email: String?
    }

    /// `"ok"`, or an object with the reason the command was refused.
    public enum CommandStatus: Decodable, Equatable, Sendable {
        case ok
        case failed(String)

        private struct Failure: Decodable {
            var error: String
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) {
                self = text == "ok" ? .ok : .failed(text)
            } else {
                self = .failed(try container.decode(Failure.self).error)
            }
        }
    }
}
