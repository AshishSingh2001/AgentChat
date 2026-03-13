import Foundation

struct CreateChatUseCase {
    let chatRepository: any ChatRepositoryProtocol

    func execute() async throws -> Chat {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let chat = Chat(
            id: UUID().uuidString,
            title: "New Chat",
            lastMessage: "",
            lastMessageTimestamp: now,
            createdAt: now,
            updatedAt: now
        )
        try await chatRepository.create(chat)
        return chat
    }
}
