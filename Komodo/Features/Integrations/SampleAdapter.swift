#if DEBUG
    import Foundation
    import KomodoCore

    /// Stands in for any provider with `-sample<Provider> YES`: three sources, and three tasks on the first sync,
    /// dated from the board's own day so `-sampleTime` places them as it would real ones. Later syncs accept every
    /// push and change nothing. Subtask IDs are unique across the whole database, so they carry the provider.
    struct SampleAdapter: ProviderAdapter {
        var provider: Provider
        var today: LocalDate

        static func sources(for provider: Provider) -> [ProviderSource] {
            let names =
                switch provider {
                case .todoist: ["Inbox", "Komodo launch", "Home"]
                case .notion: ["Reading list", "Launch plan", "Home projects"]
                case .linear: ["Design", "Engineering", "Engineering › Komodo 1.0"]
                case .clickup: ["Marketing › Content", "Product › Komodo launch", "Personal › Errands"]
                case .asana: ["Onboarding", "Komodo launch", "Website refresh"]
                }
            return names.enumerated().map { ProviderSource(id: "sample-\($0.offset)", name: $0.element) }
        }

        func sources() async throws(ProviderError) -> [ProviderSource] { Self.sources(for: provider) }

        func sync(
            _ pushes: [ExternalSync.Push], links: [ExternalLink], connection: ProviderConnection, calendar: Calendar
        ) async throws(ProviderError) -> ProviderAnswer {
            let outcomes = pushes.map { push -> ExternalSync.Outcome in
                guard case .add(let task) = push else { return .accepted }
                return .added(externalID: "sample-\(task.id)", url: URL(string: "https://example.com/\(task.id)"))
            }
            let statuses =
                provider.hasStatusMapping
                ? [
                    ProviderStatus(name: "To do", kind: .todo), ProviderStatus(name: "In progress", kind: .active),
                    ProviderStatus(name: "In review", kind: .active), ProviderStatus(name: "Done", kind: .done),
                ] : nil
            var items: [ExternalItem] = []
            if connection.cursor == nil {
                let stamp = Date(timeIntervalSince1970: 1_790_847_000)
                func url(_ id: String) -> URL? { URL(string: "https://example.com/\(provider.rawValue)/\(id)") }
                items = [
                    ExternalItem(
                        id: "sample-1", title: "Write the launch post",
                        notes: provider.shape(connection.dateMapping).fields.contains(.notes)
                            ? "Outline with Apurva" : nil, date: today, minute: provider == .linear ? nil : 15 * 60,
                        estimate: provider.shape(connection.dateMapping).fields.contains(.estimate) ? 2_700 : nil,
                        updatedAt: stamp, url: url("1"),
                        subtasks: provider.shape(connection.dateMapping).fields.contains(.subtasks)
                            ? [Subtask(id: "\(provider.rawValue)-sample-1:a", title: "Reviewed", isDone: true)] : nil),
                    ExternalItem(
                        id: "sample-2", title: "Record the demo", date: today.adding(days: 2, calendar: calendar),
                        updatedAt: stamp, url: url("2")),
                    ExternalItem(
                        id: "sample-3", title: "Collect launch quotes", updatedAt: stamp, url: url("3"),
                        bucket: provider.hasStatusMapping ? .today : nil),
                ]
            }
            return ProviderAnswer(
                outcomes: outcomes, items: items, isEverything: false, cursor: "sample-\(UUID().uuidString)",
                userID: "sample-user", statuses: statuses)
        }
    }
#endif
