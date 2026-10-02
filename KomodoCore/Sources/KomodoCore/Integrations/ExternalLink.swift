import Foundation
import GRDB

/// One provider item tied to one task (ARCHITECTURE §8).
public struct ExternalLink: Equatable, Sendable {
    /// Which connection the item belongs to, such as `todoist`.
    public var connectionID: String
    public var externalID: String
    public var taskID: String
    /// The provider's `updated_at` when the item was last read, so an older change never overwrites a newer one.
    public var remoteUpdatedAt: Date?
    /// The synced fields as both sides last agreed on them (`ExternalItem.snapshot`).
    public var snapshot: String

    public init(connectionID: String, externalID: String, taskID: String, remoteUpdatedAt: Date?, snapshot: String) {
        self.connectionID = connectionID
        self.externalID = externalID
        self.taskID = taskID
        self.remoteUpdatedAt = remoteUpdatedAt
        self.snapshot = snapshot
    }
}

extension AppDatabase {
    public func links(for connectionID: String) throws -> [ExternalLink] {
        try writer.read { db in
            try Row.fetchAll(
                db, sql: "SELECT * FROM external_links WHERE connection_id = ? ORDER BY external_id",
                arguments: [connectionID]
            ).map { row in
                ExternalLink(
                    connectionID: row["connection_id"], externalID: row["external_id"], taskID: row["task_id"],
                    remoteUpdatedAt: (row["external_updated_at"] as Double?).map(Date.init(timeIntervalSince1970:)),
                    snapshot: row["snapshot"])
            }
        }
    }

    /// Replaces a connection's links in one transaction; a connection has one project's worth, so rewriting them
    /// all is cheaper than tracking which moved.
    public func setLinks(_ links: [ExternalLink], for connectionID: String) throws {
        try writer.write { db in
            try db.execute(sql: "DELETE FROM external_links WHERE connection_id = ?", arguments: [connectionID])
            for link in links {
                try db.execute(
                    sql: """
                        INSERT INTO external_links (connection_id, external_id, task_id, external_updated_at, snapshot)
                        VALUES (?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        connectionID, link.externalID, link.taskID, link.remoteUpdatedAt?.timeIntervalSince1970,
                        link.snapshot,
                    ])
            }
        }
    }
}
