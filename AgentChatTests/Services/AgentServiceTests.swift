import Testing
import Foundation
@testable import AgentChat

@MainActor
struct AgentServiceTests {

    private func makeChat() -> Chat {
        Chat(id: "c1", title: "Hello", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
    }

    @Test func insertsAgentMessageWhenCountIsPositive() async throws {
        let msgRepo = MockMessageRepository()
        let chatRepo = MockChatRepository()
        let chat = makeChat()
        chatRepo.chats = [chat]

        let service = AgentService(
            messageRepository: msgRepo,
            chatRepository: chatRepo,
            delayRange: 0.0...0.0
        )

        await service.handleUserMessage(userMessageCount: 1, chat: chat)

        // With any RNG, count > 0 always triggers a reply per SimulateAgentReplyUseCase
        #expect(msgRepo.insertedMessages.count == 1)
        #expect(msgRepo.insertedMessages[0].sender == .agent)
        #expect(msgRepo.insertedMessages[0].chatId == "c1")
    }

    @Test func skipsInsertWhenCountIsZero() async throws {
        let msgRepo = MockMessageRepository()
        let chatRepo = MockChatRepository()
        let chat = makeChat()
        chatRepo.chats = [chat]

        let service = AgentService(
            messageRepository: msgRepo,
            chatRepository: chatRepo,
            delayRange: 0.0...0.0
        )

        await service.handleUserMessage(userMessageCount: 0, chat: chat)
        #expect(msgRepo.insertedMessages.isEmpty)
        #expect(chatRepo.updatedChat == nil)
    }

    @Test func updatesChatAfterReply() async throws {
        let msgRepo = MockMessageRepository()
        let chatRepo = MockChatRepository()
        let chat = makeChat()
        chatRepo.chats = [chat]

        let service = AgentService(
            messageRepository: msgRepo,
            chatRepository: chatRepo,
            delayRange: 0.0...0.0
        )
        await service.handleUserMessage(userMessageCount: 1, chat: chat)
        #expect(chatRepo.updatedChat?.id == "c1")
        #expect((chatRepo.updatedChat?.lastMessageTimestamp ?? 0) > 0)
    }

    @Test func usesLatestTitleNotStaleSnapshot() async throws {
        let msgRepo = MockMessageRepository()
        let chatRepo = MockChatRepository()
        let chat = makeChat()
        chatRepo.chats = [chat]

        // Simulate title being updated in DB after the reply was triggered
        let renamedChat = Chat(id: "c1", title: "Renamed Title", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        try? await chatRepo.update(renamedChat)

        let service = AgentService(
            messageRepository: msgRepo,
            chatRepository: chatRepo,
            delayRange: 0.0...0.0
        )
        // Pass original snapshot (stale title) — service should fetch fresh
        await service.handleUserMessage(userMessageCount: 1, chat: chat)
        #expect(chatRepo.updatedChat?.title == "Renamed Title")
    }

    @Test func insertedMessageIsEitherTextOrFile() async throws {
        let msgRepo = MockMessageRepository()
        let chatRepo = MockChatRepository()
        let chat = makeChat()
        chatRepo.chats = [chat]

        let service = AgentService(
            messageRepository: msgRepo,
            chatRepository: chatRepo,
            delayRange: 0.0...0.0
        )
        await service.handleUserMessage(userMessageCount: 1, chat: chat)
        let msg = msgRepo.insertedMessages[0]
        #expect(msg.type == .text || msg.type == .file)
    }

    @Test func imageReplyHasFileAttachment() async throws {
        // Use SimulateAgentReplyUseCase directly to verify image path ends up as .file message
        let msgRepo = MockMessageRepository()
        let chatRepo = MockChatRepository()
        let chat = makeChat()
        chatRepo.chats = [chat]

        // Run multiple times to hit both text and image branches; just verify structure is valid
        let service = AgentService(
            messageRepository: msgRepo,
            chatRepository: chatRepo,
            delayRange: 0.0...0.0
        )
        for i in 1...5 {
            await service.handleUserMessage(userMessageCount: i, chat: chat)
        }
        // After 5 calls, we must have 5 inserted messages all from agent
        #expect(msgRepo.insertedMessages.count == 5)
        #expect(msgRepo.insertedMessages.allSatisfy { $0.sender == .agent })
        // File messages must have a file attachment
        let fileMessages = msgRepo.insertedMessages.filter { $0.type == .file }
        #expect(fileMessages.allSatisfy { $0.file != nil })
    }
}
