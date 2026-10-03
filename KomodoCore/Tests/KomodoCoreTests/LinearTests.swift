import Foundation
import Testing

@testable import KomodoCore

struct LinearTests {
    /// The shape of an `issues` answer as Linear's schema documents it.
    let response = """
        {"data": {
          "viewer": {"id": "me"},
          "team": {"states": {"nodes": [
            {"name": "Done", "type": "completed", "position": 3},
            {"name": "Todo", "type": "unstarted", "position": 1},
            {"name": "In Progress", "type": "started", "position": 2},
            {"name": "Backlog", "type": "backlog", "position": 0}
          ]}},
          "issues": {
            "nodes": [
              {"id": "a1", "identifier": "ENG-12", "title": "Fix the login", "description": "Steps in the doc",
               "dueDate": "2026-10-02", "updatedAt": "2026-10-01T09:30:00.000Z", "archivedAt": null, "trashed": null,
               "url": "https://linear.app/komodo/issue/ENG-12", "state": {"name": "In Progress", "type": "started"},
               "assignee": {"id": "me"}},
              {"id": "a2", "identifier": "ENG-13", "title": "Old idea", "description": null, "dueDate": null,
               "updatedAt": "2026-10-01T10:00:00.000Z", "archivedAt": "2026-10-01T10:00:00.000Z", "trashed": true,
               "url": "https://linear.app/komodo/issue/ENG-13", "state": {"name": "Backlog", "type": "backlog"},
               "assignee": {"id": "someone"}}
            ],
            "pageInfo": {"hasNextPage": false, "endCursor": "c2"}
          }
        }}
        """

    @Test func anIssueBecomesAnItemPlacedByItsState() throws {
        let answer = try JSONDecoder().decode(
            Linear.Response<Linear.Issues>.self, from: Data(response.utf8))
        let issues = try #require(answer.data)
        var connection = ProviderConnection()
        connection.statuses = Linear.statuses(issues.team?.states.nodes ?? [])
        #expect(connection.statuses.map(\.name) == ["Backlog", "Todo", "In Progress", "Done"])
        let items = issues.issues.nodes.map { ExternalItem($0, viewerID: issues.viewer.id, connection: connection) }
        #expect(items[0].title == "Fix the login" && items[0].notes == "Steps in the doc")
        #expect(items[0].date == LocalDate(year: 2026, month: 10, day: 2) && items[0].bucket == .today)
        #expect(items[0].isMine && !items[0].isDone)
        #expect(items[0].url?.absoluteString == "https://linear.app/komodo/issue/ENG-12")
        #expect(items[1].isDeleted && !items[1].isMine)
        connection.statusTargets["In Progress"] = .done
        #expect(ExternalItem(issues.issues.nodes[0], viewerID: "me", connection: connection).isDone)
    }

    @Test func aChangedIssueReplacesItsOpenCopyAndMovesTheCursor() {
        let state = Linear.State(name: "Todo", type: "unstarted")
        let open = [
            Linear.Issue(
                id: "1", identifier: "E-1", title: "A", state: state, updatedAt: "2026-10-01T09:00:00.000Z", url: ""),
            Linear.Issue(
                id: "2", identifier: "E-2", title: "B", state: state, updatedAt: "2026-10-01T09:10:00.000Z", url: ""),
        ]
        let done = Linear.Issue(
            id: "1", identifier: "E-1", title: "A", state: Linear.State(name: "Done", type: "completed"),
            updatedAt: "2026-10-01T09:20:00.000Z", url: "")
        let merged = Linear.merge(open: open, changed: [done], cursor: "2026-10-01T08:00:00.000Z")
        #expect(merged.issues.map(\.state.name) == ["Done", "Todo"])
        #expect(merged.cursor == "2026-10-01T09:20:00.000Z")
    }

    @Test func aProjectNarrowsTheIssuesAndAChangeReadIncludesArchivedOnes() {
        let source = Linear.sourceID(team: "t1", project: "p1")
        let open = Linear.issuesRequest(sourceID: source, since: nil, after: nil)
        guard case .object(let filter) = open.variables["filter"] else {
            Issue.record("No filter")
            return
        }
        #expect(filter["project"] != nil && filter["state"] != nil)
        #expect(open.variables["team"] == .string("t1") && open.variables["archived"] == .bool(false))
        let changed = Linear.issuesRequest(sourceID: "t1", since: "2026-10-01T09:00:00.000Z", after: "c2")
        #expect(changed.variables["archived"] == .bool(true) && changed.variables["after"] == .string("c2"))
    }
}
