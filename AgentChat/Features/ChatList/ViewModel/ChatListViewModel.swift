import Foundation

@Observable
@MainActor
final class ChatListViewModel {
    var chats: [Chat] = []
    var isLoading = true

    private let chatRepository: any ChatRepositoryProtocol
    private let messageRepository: any MessageRepositoryProtocol
    private let createChatUseCase: CreateChatUseCase
    private let deleteChatUseCase: DeleteChatUseCase
    private let router: any AppRouterProtocol
    private var streamTask: Task<Void, Never>?

    init(
        chatRepository: any ChatRepositoryProtocol,
        messageRepository: any MessageRepositoryProtocol,
        router: any AppRouterProtocol
    ) {
        self.chatRepository = chatRepository
        self.messageRepository = messageRepository
        self.createChatUseCase = CreateChatUseCase(chatRepository: chatRepository)
        self.deleteChatUseCase = DeleteChatUseCase(chatRepository: chatRepository, messageRepository: messageRepository)
        self.router = router
    }

    func startStream() {
        streamTask?.cancel()
        streamTask = Task {
            for await updated in chatRepository.chatStream() {
                guard !Task.isCancelled else { break }
                chats = updated
                isLoading = false
            }
        }
    }

    func createNewChat() async {
        guard let chat = try? await createChatUseCase.execute() else { return }
        // Stream will update chats[]; navigate immediately since chat is already in DB
        router.push(.chatDetail(chatId: chat.id))
    }

    func deleteChat(_ chat: Chat) async {
        // Stream will remove it reactively after DB delete
        try? await deleteChatUseCase.execute(chatId: chat.id)
    }
}
