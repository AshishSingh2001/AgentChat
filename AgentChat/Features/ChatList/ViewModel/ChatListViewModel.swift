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

    func loadChats() async {
        isLoading = true
        chats = (try? await chatRepository.fetchAll()) ?? []
        isLoading = false
    }

    func createNewChat() async {
        guard let chat = try? await createChatUseCase.execute() else { return }
        chats.insert(chat, at: 0)
        router.push(.chatDetail(chatId: chat.id))
    }

    func deleteChat(_ chat: Chat) async {
        chats.removeAll { $0.id == chat.id }
        try? await deleteChatUseCase.execute(chatId: chat.id)
    }
}
