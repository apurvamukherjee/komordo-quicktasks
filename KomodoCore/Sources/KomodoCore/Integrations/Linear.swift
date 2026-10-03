import Foundation

/// Linear's GraphQL API (linear.app/developers), read only: Linear → Komodo (FEATURES §5). Each poll reads the
/// team's open issues, so a deleted one shows by being missing, and every issue changed since the last poll,
/// finished and archived ones included.
public enum Linear {
    public static let url = URL(string: "https://api.linear.app/graphql")
    public static let tokenHelpURL = URL(string: "https://linear.app/settings/account/security")

    /// `{"query": …, "variables": …}`.
    public struct Request: Encodable, Sendable {
        public var query: String
        public var variables: [String: JSONValue]

        public init(query: String, variables: [String: JSONValue]) {
            self.query = query
            self.variables = variables
        }
    }

    /// Every response has `data`, or `errors` with a message each.
    public struct Response<Payload: Decodable & Sendable>: Decodable, Sendable {
        public var data: Payload?
        public var errors: [Message]?

        public struct Message: Decodable, Sendable {
            public var message: String
        }
    }

    public struct Connection<Node: Decodable & Sendable>: Decodable, Sendable {
        public var nodes: [Node]
        public var pageInfo: PageInfo?

        public struct PageInfo: Decodable, Sendable {
            public var hasNextPage: Bool
            public var endCursor: String?
        }
    }

    // MARK: Teams, for the token sheet

    public static let teamsQuery = """
        query Teams {
          viewer { id }
          teams(first: 100) { nodes { id name projects(first: 100) { nodes { id name status { type } } } } }
        }
        """

    public struct Teams: Decodable, Sendable {
        public var viewer: Viewer
        public var teams: Connection<Team>
    }

    public struct Viewer: Decodable, Equatable, Sendable {
        public var id: String
    }

    public struct Team: Decodable, Sendable {
        public var id: String
        public var name: String
        public var projects: Connection<Project>?
    }

    public struct Project: Decodable, Sendable {
        public var id: String
        public var name: String
        public var status: Status?

        public struct Status: Decodable, Sendable {
            /// `backlog`, `planned`, `started`, `paused`, `completed` or `canceled`.
            public var type: String
        }

        public var isFinished: Bool { ["completed", "canceled"].contains(status?.type ?? "") }
    }

    /// The source ID: a team, or a team's project as `team/project`.
    public static func sourceID(team: String, project: String? = nil) -> String {
        project.map { "\(team)/\($0)" } ?? team
    }

    static func parts(of sourceID: String) -> (team: String, project: String?) {
        let parts = sourceID.split(separator: "/", maxSplits: 1).map(String.init)
        return (parts[0], parts.count > 1 ? parts[1] : nil)
    }

    // MARK: Issues

    public struct Issues: Decodable, Sendable {
        public var viewer: Viewer
        public var team: TeamStates?
        public var issues: Connection<Issue>
    }

    public struct TeamStates: Decodable, Sendable {
        public var states: Connection<State>
    }

    public struct State: Decodable, Equatable, Sendable {
        public var name: String
        /// `triage`, `backlog`, `unstarted`, `started`, `completed` or `canceled`.
        public var type: String
        public var position: Double?

        public init(name: String, type: String, position: Double? = nil) {
            self.name = name
            self.type = type
            self.position = position
        }
    }

    public struct Issue: Decodable, Equatable, Sendable {
        public var id: String
        public var identifier: String
        public var title: String
        public var description: String?
        /// `2026-10-02`.
        public var dueDate: String?
        public var state: State
        public var assignee: Viewer?
        public var updatedAt: String
        public var archivedAt: String?
        public var trashed: Bool?
        public var url: String

        public init(
            id: String, identifier: String, title: String, description: String? = nil, dueDate: String? = nil,
            state: State, assignee: String? = nil, updatedAt: String, archivedAt: String? = nil,
            trashed: Bool? = nil, url: String
        ) {
            self.id = id
            self.identifier = identifier
            self.title = title
            self.description = description
            self.dueDate = dueDate
            self.state = state
            self.assignee = assignee.map(Viewer.init)
            self.updatedAt = updatedAt
            self.archivedAt = archivedAt
            self.trashed = trashed
            self.url = url
        }
    }

    /// One page of issues. With `since`, every issue changed after it, archived ones included; without, the open
    /// ones. The team's workflow states come along, for the status mapping.
    public static func issuesRequest(sourceID: String, since: String?, after: String?) -> Request {
        let (team, project) = parts(of: sourceID)
        var filter: [String: JSONValue] = ["team": .object(["id": .object(["eq": .string(team)])])]
        if let project { filter["project"] = .object(["id": .object(["eq": .string(project)])]) }
        if let since {
            filter["updatedAt"] = .object(["gt": .string(since)])
        } else {
            filter["state"] = .object(["type": .object(["nin": .array([.string("completed"), .string("canceled")])])])
        }
        return Request(
            query: """
                query Issues($team: String!, $filter: IssueFilter, $after: String, $archived: Boolean) {
                  viewer { id }
                  team(id: $team) { states(first: 100) { nodes { name type position } } }
                  issues(first: 100, after: $after, filter: $filter, includeArchived: $archived) {
                    nodes {
                      id identifier title description dueDate updatedAt archivedAt trashed url
                      state { name type }
                      assignee { id }
                    }
                    pageInfo { hasNextPage endCursor }
                  }
                }
                """,
            variables: [
                "team": .string(team), "filter": .object(filter), "after": after.map(JSONValue.string) ?? .null,
                "archived": .bool(since != nil),
            ])
    }

    public static func kind(ofStateType type: String) -> ProviderStatus.Kind {
        switch type {
        case "started": .active
        case "completed", "canceled": .done
        default: .todo
        }
    }

    /// The open issues with what changed since the last poll, a changed one replacing its open copy, and where the
    /// next poll starts: the latest change seen.
    public static func merge(
        open: [Issue], changed: [Issue], cursor: String?
    ) -> (issues: [Issue], cursor: String?) {
        var issues = open.filter { issue in !changed.contains { $0.id == issue.id } } + changed
        issues.sort { $0.id < $1.id }
        // ISO 8601 in UTC sorts as text.
        let latest = (issues.map(\.updatedAt) + [cursor].compactMap { $0 }).max()
        return (issues, latest)
    }

    /// The team's states in Linear's order.
    public static func statuses(_ states: [State]) -> [ProviderStatus] {
        states.sorted { ($0.position ?? 0) < ($1.position ?? 0) }.map {
            ProviderStatus(name: $0.name, kind: kind(ofStateType: $0.type))
        }
    }
}

extension ExternalItem {
    /// A Linear issue: its due date schedules it, since Linear has no other date, and its state places it through
    /// the status mapping. An archived or trashed issue counts as deleted.
    public init(_ issue: Linear.Issue, viewerID: String?, connection: ProviderConnection) {
        let status = ProviderStatus(name: issue.state.name, kind: Linear.kind(ofStateType: issue.state.type))
        let target = connection.target(for: status)
        self.init(
            id: issue.id, title: issue.title,
            notes: issue.description.flatMap { $0.isEmpty ? nil : $0 },
            date: issue.dueDate.flatMap { LocalDate(iso: String($0.prefix(10))) }, isDone: target == .done,
            isDeleted: issue.archivedAt != nil || issue.trashed == true,
            isMine: issue.assignee == nil || issue.assignee?.id == viewerID,
            updatedAt: ExternalItem.instant(issue.updatedAt), url: URL(string: issue.url), bucket: target.bucket)
    }
}
