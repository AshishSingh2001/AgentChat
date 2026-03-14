import Testing
import Foundation
@testable import AgentChat

@MainActor
struct SendMessageUseCaseTests {

    private func makeChat() -> Chat {
        Chat(id: "chat-1", title: "New Chat", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
    }

    @Test func insertsMessage() async throws {
        let chatRepo = MockChatRepository()
        let msgRepo = MockMessageRepository()
        let useCase = SendMessageUseCase(chatRepository: chatRepo, messageRepository: msgRepo)
        let chat = makeChat()
        chatRepo.chats = [chat]

        let (message, _) = try await useCase.execute(text: "Hello", chat: chat, existingMessageCount: 0)
        #expect(message.text == "Hello")
        #expect(message.sender == .user)
        #expect(message.chatId == "chat-1")
        #expect(msgRepo.insertedMessages.count == 1)
    }

    @Test func updatesChatLastMessage() async throws {
        let chatRepo = MockChatRepository()
        let msgRepo = MockMessageRepository()
        let useCase = SendMessageUseCase(chatRepository: chatRepo, messageRepository: msgRepo)
        let chat = makeChat()
        chatRepo.chats = [chat]

        let (_, updatedChat) = try await useCase.execute(text: "Hello", chat: chat, existingMessageCount: 0)
        #expect(updatedChat.lastMessage == "Hello")
        #expect(chatRepo.updatedChat?.lastMessage == "Hello")
    }

    @Test func autoTitlesOnFirstMessage() async throws {
        let chatRepo = MockChatRepository()
        let msgRepo = MockMessageRepository()
        let useCase = SendMessageUseCase(chatRepository: chatRepo, messageRepository: msgRepo)
        let chat = makeChat()
        chatRepo.chats = [chat]

        let (_, updatedChat) = try await useCase.execute(
            text: "Book a flight to Mumbai",
            chat: chat,
            existingMessageCount: 0
        )
        #expect(updatedChat.title == "Book a flight to Mumbai")
    }

    @Test func titleTruncatedTo30Chars() async throws {
        let chatRepo = MockChatRepository()
        let msgRepo = MockMessageRepository()
        let useCase = SendMessageUseCase(chatRepository: chatRepo, messageRepository: msgRepo)
        let chat = makeChat()
        chatRepo.chats = [chat]

        let longText = "This is a very long message that exceeds thirty characters easily"
        let (_, updatedChat) = try await useCase.execute(text: longText, chat: chat, existingMessageCount: 0)
        #expect(updatedChat.title.count <= 30)
    }

    @Test func doesNotOverwriteTitleOnSubsequentMessages() async throws {
        let chatRepo = MockChatRepository()
        let msgRepo = MockMessageRepository()
        let useCase = SendMessageUseCase(chatRepository: chatRepo, messageRepository: msgRepo)
        let chat = Chat(id: "chat-1", title: "Custom Title", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        chatRepo.chats = [chat]

        let (_, updatedChat) = try await useCase.execute(
            text: "Second message",
            chat: chat,
            existingMessageCount: 1
        )
        #expect(updatedChat.title == "Custom Title")
    }

    @Test func emptyTextAndNoFileThrows() async throws {
        let chatRepo = MockChatRepository()
        let msgRepo = MockMessageRepository()
        let useCase = SendMessageUseCase(chatRepository: chatRepo, messageRepository: msgRepo)
        let chat = makeChat()
        chatRepo.chats = [chat]

        var threw = false
        do {
            _ = try await useCase.execute(text: "", file: nil, chat: chat, existingMessageCount: 0)
        } catch SendMessageError.emptyMessage {
            threw = true
        }
        #expect(threw)
    }
}
