import SwiftUI
import SwiftData

@main
struct AgentChatApp: App {
    let container: ModelContainer
    let chatRepository: SwiftDataChatRepository
    let messageRepository: SwiftDataMessageRepository
    let fileStorageService: FileStorageService
    @State private var router = AppRouter()

    init() {
        do {
            container = try ModelContainer(for: ChatEntity.self, MessageEntity.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        chatRepository = SwiftDataChatRepository(modelContainer: container)
        messageRepository = SwiftDataMessageRepository(modelContainer: container)
        fileStorageService = FileStorageService()
    }

    var body: some Scene {
        WindowGroup {
            AppView(
                chatRepository: chatRepository,
                messageRepository: messageRepository,
                fileStorageService: fileStorageService
            )
            .environment(router)
            .task {
                let seeder = SeedDataLoader(modelContainer: container)
                try? await seeder.loadIfNeeded()
            }
        }
    }
}
