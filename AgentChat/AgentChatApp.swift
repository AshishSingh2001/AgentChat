import SwiftUI

@main
struct AgentChatApp: App {
    private let persistence = PersistenceController()
    private let fileStorageService = FileStorageService()
    @State private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            AppView(
                chatRepository: persistence.chatRepository,
                messageRepository: persistence.messageRepository,
                fileStorageService: fileStorageService
            )
            .environment(router)
            .onAppear {
                let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting-reset")
                persistence.seedInBackground(resetForTesting: isUITesting)
            }
        }
    }
}
