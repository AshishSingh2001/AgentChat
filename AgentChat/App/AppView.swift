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
                    ChatDetailView(
                        chatId: chatId,
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
