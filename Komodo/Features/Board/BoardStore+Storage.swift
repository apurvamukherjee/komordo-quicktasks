import Foundation
import KomodoCore
import OSLog

extension BoardStore {
    /// Komodo's database in Application Support.
    static var databaseURL: URL {
        get throws {
            #if DEBUG
                // `-databasePath <file>` tries persistence, crash recovery and reminders on a scratch file.
                if let path = UserDefaults.standard.string(forKey: "databasePath") { return URL(filePath: path) }
            #endif
            return try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appending(path: "Komodo/Komodo.sqlite")
        }
    }

    /// The store for real use: everything loads from the database and every change is written back. The first
    /// launch starts with one list, "Personal", until onboarding asks for lists.
    static func persistent() -> BoardStore {
        do {
            let database = try AppDatabase.open(at: databaseURL)
            let stored = try database.load()
            let lists = stored.lists.isEmpty ? [firstList] : stored.lists
            let store = BoardStore(
                lists: lists, tasks: stored.tasks, selectedListID: lists.first?.id, database: database,
                preferences: stored.preferences,
                trash: stored.trash.sorted { $0.deletedAt ?? .now > $1.deletedAt ?? .now },
                archived: stored.archived)
            store.persist(.lists(from: stored.lists, to: lists))
            return store
        } catch {
            // Without the file the app still opens, in memory, and says so rather than failing to launch.
            Logger(subsystem: "app.komodo.Komodo", category: "storage").error("Couldn't open the database: \(error)")
            let store = BoardStore(lists: [firstList], tasks: [], selectedListID: firstList.id)
            store.toasts.show(
                Toast(
                    kind: .error, message: "Couldn't open your tasks",
                    detail: "Changes won't be saved until Komodo restarts."))
            return store
        }
    }

    private static var firstList: TaskList { TaskList(id: UUID().uuidString, name: "Personal", color: "teal") }
}
