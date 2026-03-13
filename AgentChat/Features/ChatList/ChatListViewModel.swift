import Foundation

@Observable
@MainActor
final class ChatListViewModel {
    var chats: [Chat] = []
    var chatPendingDeletion: Chat?

    private let chatRepository: any ChatRepositoryProtocol
    private let messageRepository: any MessageRepositoryProtocol
    private let createChatUseCase: CreateChatUseCase
    private let router: any AppRouterProtocol

    init(
        chatRepository: any ChatRepositoryProtocol,
        messageRepository: any MessageRepositoryProtocol,
        router: any AppRouterProtocol
    ) {
        self.chatRepository = chatRepository
        self.messageRepository = messageRepository
        self.createChatUseCase = CreateChatUseCase(chatRepository: chatRepository)
        self.router = router
    }

    func loadChats() async {
        chats = (try? await chatRepository.fetchAll()) ?? []
    }

    func createNewChat() async {
        guard let chat = try? await createChatUseCase.execute() else { return }
        chats.insert(chat, at: 0)
        router.push(.chatDetail(chatId: chat.id))
    }

    func requestDeleteChat(_ chat: Chat) {
        chatPendingDeletion = chat
    }

    func confirmDeleteChat() async {
        guard let chat = chatPendingDeletion else { return }
        try? await chatRepository.delete(id: chat.id)
        try? await messageRepository.deleteAll(for: chat.id)
        chats.removeAll { $0.id == chat.id }
        chatPendingDeletion = nil
    }

    func cancelDeleteChat() {
        chatPendingDeletion = nil
    }
}
