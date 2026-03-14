import Foundation
import SwiftData

/// Owns the ModelContainer and vends repositories.
@MainActor
final class PersistenceController {
    let container: ModelContainer
    let chatRepository: SwiftDataChatRepository
    let messageRepository: SwiftDataMessageRepository

    init() {
        do {
            container = try ModelContainer(for: ChatEntity.self, MessageEntity.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        chatRepository = SwiftDataChatRepository(modelContainer: container)
        messageRepository = SwiftDataMessageRepository(modelContainer: container)
    }

    /// Seeds data. Awaitable: caller can wait for completion before proceeding.
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
    }
}
