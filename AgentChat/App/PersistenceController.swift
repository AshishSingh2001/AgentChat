import Foundation
import SwiftData

/// Owns the ModelContainer, vends repositories, and seeds data in the background.
/// App launch is never blocked — seeding runs asynchronously and notifies via
/// `Notification.Name.seedDataLoaded` when complete.
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

    /// Seeds data in the background. Never blocks the caller.
    /// Posts `.seedDataLoaded` when done so the chat list can reload.
    func seedInBackground(resetForTesting: Bool = false) {
        let container = self.container
        Task.detached {
            let seeder = SeedDataLoader(modelContainer: container)
            if resetForTesting {
                UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
                try? await seeder.resetAndReload()
            } else {
                try? await seeder.loadIfNeeded()
            }
            await MainActor.run {
                NotificationCenter.default.post(name: .seedDataLoaded, object: nil)
            }
        }
    }
}

extension Notification.Name {
    static let seedDataLoaded = Notification.Name("agentchat.seedDataLoaded")
}
