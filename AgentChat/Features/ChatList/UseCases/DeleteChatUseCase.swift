import Foundation

struct DeleteChatUseCase {
    let chatRepository: any ChatRepositoryProtocol
    let messageRepository: any MessageRepositoryProtocol

    func execute(chatId: String) async throws {
        try await messageRepository.deleteAll(for: chatId)
        try await chatRepository.delete(id: chatId)
    }
}
