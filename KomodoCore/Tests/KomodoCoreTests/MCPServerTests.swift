import Foundation
import Testing

@testable import KomodoCore

struct MCPServerTests {
    private let work = TaskList(id: "work", name: "Work", color: "lime")
    // Thursday 1 October 2026, 10:00 in UTC.
    private let now = Date(timeIntervalSince1970: 1_790_848_800)
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private func server(enabled: Bool = true) throws -> (MCPServer, AppDatabase) {
        let database = try AppDatabase.inMemory()
        var change = BoardChange.lists(from: [], to: [work])
        change.savedTasks = [
            TaskItem(
                id: "spec", listID: "work", title: "Write spec", bucket: .today, rank: 1, estimate: 2_700,
                subtasks: [Subtask(id: "outline", title: "Outline")])
        ]
        try database.apply(change)
        if enabled { try database.setPreference("1", for: "mcpEnabled") }
        let now = self.now
        let tools = KomodoTools(database: database, calendar: calendar, now: { now })
        return (MCPServer(tools: tools, version: "1.0.0"), database)
    }

    private func send(_ server: MCPServer, _ method: String, _ params: JSONValue = [:], id: Int = 1) throws -> JSONValue
    {
        let request: JSONValue = ["jsonrpc": "2.0", "id": .int(id), "method": .string(method), "params": params]
        let reply = server.handle(try JSONEncoder().encode(request))
        let line = try #require(reply.line)
        #expect(!line.contains(UInt8(ascii: "\n")))
        return try JSONDecoder().decode(JSONValue.self, from: line)
    }

    /// A tool's text, decoded as the JSON it carries.
    private func call(_ server: MCPServer, _ name: String, _ arguments: JSONValue = [:]) throws -> JSONValue {
        let response = try send(server, "tools/call", ["name": .string(name), "arguments": arguments])
        #expect(response["result"]?["isError"] == false)
        let text = try #require(response["result"]?["content"]?.array?.first?["text"]?.string)
        return try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }

    @Test func itIntroducesItselfAndListsItsTools() throws {
        let (server, _) = try server()
        let hello = try send(server, "initialize", ["protocolVersion": "2025-03-26"])
        #expect(hello["id"] == 1)
        #expect(hello["result"]?["protocolVersion"] == "2025-03-26")
        #expect(hello["result"]?["serverInfo"]?["name"] == "komodo")
        let names = try send(server, "tools/list")["result"]?["tools"]?.array?.compactMap { $0["name"]?.string }
        #expect(
            names == [
                "list_lists", "list_tasks", "create_task", "update_task", "complete_task", "complete_subtask",
                "log_time", "start_focus",
            ])
    }

    @Test func notificationsAndNonsenseGetTheRightAnswers() throws {
        let (server, _) = try server()
        #expect(server.handle(Data(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#.utf8)).line == nil)
        #expect(try send(server, "resources/list")["error"]?["code"] == -32601)
        let garbage = try #require(server.handle(Data("not json".utf8)).line)
        #expect(try JSONDecoder().decode(JSONValue.self, from: garbage)["error"]?["code"] == -32700)
    }

    @Test func everyToolWaitsForTheSwitch() throws {
        let (server, _) = try server(enabled: false)
        let response = try send(server, "tools/call", ["name": "list_lists"])
        #expect(response["result"]?["isError"] == true)
        #expect(response["result"]?["content"]?.array?.first?["text"]?.string?.contains("Settings") == true)
    }

    @Test func createUpdateAndCompleteATask() throws {
        let (server, database) = try server()
        #expect(try call(server, "list_lists") == [["id": "work", "name": "Work", "color": "lime", "badge": "W"]])

        let created = try call(
            server, "create_task",
            [
                "title": "Review Apurva's draft 30m", "subtasks": ["Read", "Comment"], "date": "2026-10-02",
                "time": "14:30",
            ])
        #expect(created["title"] == "Review Apurva's draft")
        #expect(created["estimate_minutes"] == 30)
        #expect(created["column"] == "week")
        #expect(created["time"] == "14:30")
        let id = try #require(created["id"]?.string)

        let moved = try call(server, "update_task", ["id": .string(id), "column": "today", "notes": "See the doc"])
        #expect(moved["column"] == "today")
        #expect(moved["date"] == nil)
        #expect(moved["notes"] == "See the doc")

        let subtaskID = try #require(moved["subtasks"]?.array?.first?["id"]?.string)
        _ = try call(server, "complete_subtask", ["task_id": .string(id), "subtask_id": .string(subtaskID)])
        _ = try call(server, "log_time", ["task_id": .string(id), "minutes": 25])
        let done = try call(server, "complete_task", ["id": .string(id)])
        #expect(done["done"] == true)
        #expect(done["time_taken_minutes"] == 25)

        let stored = try #require(try database.load().tasks.first { $0.id == id })
        #expect(stored.subtasks.first?.isDone == true)
        #expect(stored.completedAt == now)
        #expect(try call(server, "list_tasks", ["column": "today"]).array?.count == 1)
        #expect(try call(server, "list_tasks", ["status": "done"]).array?.count == 1)
    }

    @Test func writesAreFlaggedAndStartGoesThroughTheApp() throws {
        let (server, _) = try server()
        let read = server.tools.call("list_tasks", arguments: [:])
        #expect(!read.changedBoard)
        let wrote = server.tools.call("complete_subtask", arguments: ["task_id": "spec", "subtask_id": "outline"])
        #expect(wrote.changedBoard)
        let start = server.tools.call("start_focus", arguments: ["task_id": "spec"])
        #expect(start.opens == URL(string: "komodo://start?task=spec"))
        #expect(!start.changedBoard)
    }

    @Test func badArgumentsSayWhatsWrong() throws {
        let (server, _) = try server()
        let cases: [(String, JSONValue, String)] = [
            ("create_task", [:], "title is required."),
            ("create_task", ["title": "x", "list_id": "nope"], "No list nope"),
            ("update_task", ["id": "nope"], "No task nope"),
            ("create_task", ["title": "x", "time": "14:30"], "A time needs a date too."),
            ("create_task", ["title": "x", "date": "2026-10-02", "time": "25:00"], "time is HH:MM"),
            ("log_time", ["task_id": "spec", "minutes": 0], "minutes is a number"),
            ("list_tasks", ["column": "later"], "column is backlog, week or today."),
        ]
        for (name, arguments, message) in cases {
            let outcome = server.tools.call(name, arguments: arguments)
            #expect(outcome.isError)
            #expect(outcome.text.contains(message), "\(name): \(outcome.text)")
        }
    }
}
