import Foundation
import SwiftData

/// Owns the ModelContainer, vends repositories, and coordinates seed readiness.
@MainActor
final class PersistenceController {
    let container: ModelContainer
    let chatRepository: SwiftDataChatRepository
    let messageRepository: SwiftDataMessageRepository
    let databaseInitializer: DatabaseInitializer

    init() {
        let initializer = DatabaseInitializer()
        self.databaseInitializer = initializer
        do {
            container = try ModelContainer(for: ChatEntity.self, MessageEntity.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        chatRepository = SwiftDataChatRepository(modelContainer: container, initializer: initializer)
        messageRepository = SwiftDataMessageRepository(modelContainer: container, initializer: initializer)
    }

    /// Seeds data then marks the DB as ready, unblocking any pending repository calls.
    func seed(resetForTesting: Bool = false) async {
        let container = self.container
        await Task.detached {
            let seeder = SeedDataLoader(modelContainer: container)
            if resetForTesting {
                UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
                try? await seeder.resetAndReload()
            } else {
                try? await seeder.loadIfNeeded()
            }
        }.value
        await databaseInitializer.markReady()
    }
}
