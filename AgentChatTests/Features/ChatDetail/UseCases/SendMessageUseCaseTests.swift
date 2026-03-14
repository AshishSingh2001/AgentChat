import Testing
import Foundation
@testable import AgentChat

@MainActor
struct SendMessageUseCaseTests {

    private func makeChat(title: String = "New Chat") -> Chat {
        Chat(id: "chat-1", title: title, lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
    }

    @Test func insertsMessage() async throws {
        let chatRepo = MockChatRepository()
        let msgRepo = MockMessageRepository()
        let useCase = SendMessageUseCase(chatRepository: chatRepo, messageRepository: msgRepo)
        let chat = makeChat()
        chatRepo.chats = [chat]

        let (message, _) = try await useCase.execute(text: "Hello", chat: chat, isFirstMessage: true)
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

        let (_, updatedChat) = try await useCase.execute(text: "Hello", chat: chat, isFirstMessage: true)
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
            isFirstMessage: true
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
        let (_, updatedChat) = try await useCase.execute(text: longText, chat: chat, isFirstMessage: true)
        #expect(updatedChat.title.count <= 30)
    }

    @Test func doesNotOverwriteTitleOnSubsequentMessages() async throws {
        let chatRepo = MockChatRepository()
        let msgRepo = MockMessageRepository()
        let useCase = SendMessageUseCase(chatRepository: chatRepo, messageRepository: msgRepo)
        let chat = makeChat(title: "Custom Title")
        chatRepo.chats = [chat]

        let (_, updatedChat) = try await useCase.execute(
            text: "Second message",
            chat: chat,
            isFirstMessage: false
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
            _ = try await useCase.execute(text: "", file: nil, chat: chat, isFirstMessage: true)
        } catch SendMessageError.emptyMessage {
            threw = true
        }
        #expect(threw)
    }
}
