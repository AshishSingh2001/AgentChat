import Foundation

@Observable
@MainActor
final class ChatListViewModel {
    var chats: [Chat] = []
    var isLoading = true
    var errorMessage: String?

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

    func navigateToChat(_ chat: Chat) {
        router.push(.chatDetail(chat: chat))
    }

    func createNewChat() async {
        do {
            let chat = try await createChatUseCase.execute()
            router.push(.chatDetail(chat: chat))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteChat(_ chat: Chat) async {
        do {
            try await deleteChatUseCase.execute(chatId: chat.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissError() {
        errorMessage = nil
    }
}
