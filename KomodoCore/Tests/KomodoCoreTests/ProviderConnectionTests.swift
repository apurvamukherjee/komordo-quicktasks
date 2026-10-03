import Testing

@testable import KomodoCore

struct ProviderConnectionTests {
    var connection: ProviderConnection {
        var connection = ProviderConnection()
        connection.statuses = [
            ProviderStatus(name: "Backlog", kind: .todo), ProviderStatus(name: "Todo", kind: .todo),
            ProviderStatus(name: "Doing", kind: .active), ProviderStatus(name: "Done", kind: .done),
            ProviderStatus(name: "Cancelled", kind: .done),
        ]
        return connection
    }

    @Test func eachKindHasADefaultPlace() {
        #expect(connection.statuses.map(connection.target) == [.byDate, .byDate, .today, .done, .done])
    }

    @Test func aStatusIsSentForWhereTheTaskWent() {
        var connection = connection
        #expect(connection.status(for: .today, isDone: false)?.name == "Doing")
        #expect(connection.status(for: .week, isDone: false)?.name == "Backlog")
        #expect(connection.status(for: .backlog, isDone: true)?.name == "Done")
        connection.statusTargets = ["Todo": .week, "Done": .byDate]
        #expect(connection.status(for: .week, isDone: false)?.name == "Todo")
        #expect(connection.status(for: .backlog, isDone: true)?.name == "Cancelled")
    }

    @Test func noStatusesLeavesTheProvidersAlone() {
        #expect(ProviderConnection().status(for: .today, isDone: true) == nil)
    }
}
