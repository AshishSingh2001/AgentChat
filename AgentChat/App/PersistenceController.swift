import Foundation
import GRDB

/// Owns the AppDatabase, vends repositories, and seeds initial data.
@MainActor
final class PersistenceController {
    let appDatabase: AppDatabase
    let chatRepository: GRDBChatRepository
    let messageRepository: GRDBMessageRepository

    init() {
        do {
            appDatabase = try AppDatabase.onDisk()
        } catch {
            fatalError("Failed to open database: \(error)")
        }
        chatRepository = GRDBChatRepository(appDatabase: appDatabase)
        messageRepository = GRDBMessageRepository(appDatabase: appDatabase)
    }

    /// Seeds data on first launch. Synchronous — GRDB migrations already ran in AppDatabase.init.
    func seed(resetForTesting: Bool = false) {
        let seeder = SeedDataLoader(appDatabase: appDatabase)
        if resetForTesting {
            UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
            try? seeder.resetAndReload()
        } else {
            try? seeder.loadIfNeeded()
        }
    }
}
