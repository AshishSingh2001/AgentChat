import SwiftUI

struct AppView: View {
    @Environment(AppRouter.self) private var router
    let chatRepository: any ChatRepositoryProtocol
    let messageRepository: any MessageRepositoryProtocol
    let fileStorageService: FileStorageService

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            ChatListView(
                chatRepository: chatRepository,
                messageRepository: messageRepository,
                router: router
            )
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case .chatDetail(let chatId):
                    if let chat = findChat(id: chatId) {
                        ChatDetailView(
                            chat: chat,
                            chatRepository: chatRepository,
                            messageRepository: messageRepository,
                            router: router,
                            fileStorageService: fileStorageService
                        )
                    }
                }
            }
        }
    }

    // Note: In Phase 6, the chat list VM holds the chats.
    // For navigation destination we look up from the seed data via a fetch.
    // This is a temporary approach — Phase 7 will refine via ChatDetailViewModel.loadMessages().
    // We pass a placeholder Chat and let ChatDetailView.loadMessages() hydrate from the repo.
    private func findChat(id: String) -> Chat? {
        Chat(id: id, title: "", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
    }
}
