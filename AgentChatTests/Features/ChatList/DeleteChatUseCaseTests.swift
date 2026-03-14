import Testing
import Foundation
@testable import AgentChat

@MainActor
struct DeleteChatUseCaseTests {

    @Test func executeDeletesMessagesBeforeChat() async throws {
        let chatRepo = MockChatRepository()
        let msgRepo = MockMessageRepository()
        let chat = Chat(id: "c1", title: "Test", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        chatRepo.chats = [chat]
        msgRepo.messagesByChat["c1"] = [
            Message(id: "m1", chatId: "c1", text: "Hi", type: .text, file: nil, sender: .user, timestamp: 0)
        ]

        let useCase = DeleteChatUseCase(chatRepository: chatRepo, messageRepository: msgRepo)
        try await useCase.execute(chatId: "c1")

        #expect(chatRepo.deletedId == "c1")
        #expect(msgRepo.deletedChatIds.contains("c1"))
    }

    @Test func executeRemovesChatFromRepository() async throws {
        let chatRepo = MockChatRepository()
        let msgRepo = MockMessageRepository()
        let chat = Chat(id: "c2", title: "Test2", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        chatRepo.chats = [chat]

        let useCase = DeleteChatUseCase(chatRepository: chatRepo, messageRepository: msgRepo)
        try await useCase.execute(chatId: "c2")

        #expect(chatRepo.chats.isEmpty)
    }
}
