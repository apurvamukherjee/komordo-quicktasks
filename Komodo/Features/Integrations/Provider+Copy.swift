import Foundation
import KomodoCore

/// How the Integrations page and the token sheet name each provider and what it syncs.
extension Provider {
    var name: String { source.title }
    var letter: String { String(name.prefix(1)) }

    /// What one connection syncs with a list, as the token sheet's picker names it.
    var sourceNoun: String {
        switch self {
        case .todoist, .asana: "Project"
        case .notion: "Database"
        case .linear: "Team"
        case .clickup: "List"
        }
    }

    var cardDetail: String {
        switch self {
        case .todoist: "Sync one project with a list, both ways."
        case .notion: "Sync a database with a list, both ways."
        case .linear: "Import a team's issues into a list."
        case .clickup: "Sync a ClickUp list with a list here, both ways."
        case .asana: "Sync a project with a list, both ways."
        }
    }

    /// "Two-way · one project · polled every 5 min".
    var sheetSubtitle: String {
        "\(isTwoWay ? "Two-way" : "Into Komodo") · one \(sourceNoun.lowercased()) · polled every 5 min"
    }

    /// What the provider calls the token and where the sheet sends the user for it.
    var tokenName: String {
        switch self {
        case .notion: "integration secret"
        case .linear, .clickup: "API key"
        case .asana: "personal access token"
        case .todoist: "API token"
        }
    }

    var tokenHelpURL: URL? {
        switch self {
        case .todoist: Todoist.tokenHelpURL
        case .notion: Notion.tokenHelpURL
        case .linear: Linear.tokenHelpURL
        case .clickup: ClickUp.tokenHelpURL
        case .asana: Asana.tokenHelpURL
        }
    }

    /// A step the token alone doesn't cover.
    var tokenNote: String? {
        self == .notion ? "Share the database with your integration in Notion first, from its ••• menu." : nil
    }

    var itemNoun: String { self == .linear ? "issues" : "tasks" }
}
