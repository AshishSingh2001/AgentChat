import Testing
import Foundation
@testable import AgentChat

// A decider that always replies with a fixed text response — isolates AgentService logic
// from SimulateAgentReplyUseCase interval logic.
private struct AlwaysReplyDecider: AgentDecider {
    func decide(userMessagesSinceLastReply: Int, using rng: inout some RandomNumberGenerator) -> AgentReplyDecision {
        guard userMessagesSinceLastReply > 0 else {
            return AgentReplyDecision(shouldReply: false, replyType: .text(""))
        }
        return AgentReplyDecision(shouldReply: true, replyType: .text("Hello from agent"))
    }
}

private struct AlwaysImageDecider: AgentDecider {
    func decide(userMessagesSinceLastReply: Int, using rng: inout some RandomNumberGenerator) -> AgentReplyDecision {
        guard userMessagesSinceLastReply > 0 else {
            return AgentReplyDecision(shouldReply: false, replyType: .text(""))
        }
        return AgentReplyDecision(shouldReply: true, replyType: .image("https://picsum.photos/400/300"))
    }
}

@MainActor
struct AgentServiceTests {

    private func makeChat() -> Chat {
        Chat(id: "c1", title: "Hello", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
    }

    private func seedUserMessage(in repo: MockMessageRepository, chatId: String, timestamp: Int64 = 1000) {
        repo.messagesByChat[chatId, default: []].append(
            Message(id: UUID().uuidString, chatId: chatId, text: "Hi", type: .text, file: nil, sender: .user, timestamp: timestamp)
        )
    }

    @Test func insertsAgentMessageWhenDeciderSaysReply() async throws {
        let msgRepo = MockMessageRepository()
        let chatRepo = MockChatRepository()
        let chat = makeChat()
        chatRepo.chats = [chat]
        seedUserMessage(in: msgRepo, chatId: chat.id)

        let service = AgentService(
            messageRepository: msgRepo,
            chatRepository: chatRepo,
            delayRange: 0.0...0.0,
            decider: AlwaysReplyDecider()
        )

        service.handleUserMessage(chat: chat)
        try await Task.sleep(for: .milliseconds(200))

        #expect(msgRepo.insertedMessages.count == 1)
        #expect(msgRepo.insertedMessages[0].sender == .agent)
        #expect(msgRepo.insertedMessages[0].chatId == "c1")
    }

    @Test func skipsInsertWhenNoUserMessages() async throws {
        let msgRepo = MockMessageRepository()
        let chatRepo = MockChatRepository()
        let chat = makeChat()
        chatRepo.chats = [chat]
        // no messages seeded

        let service = AgentService(
            messageRepository: msgRepo,
            chatRepository: chatRepo,
            delayRange: 0.0...0.0,
            decider: AlwaysReplyDecider()
        )

        service.handleUserMessage(chat: chat)
        try await Task.sleep(for: .milliseconds(200))
        #expect(msgRepo.insertedMessages.isEmpty)
        #expect(chatRepo.updatedChat == nil)
    }

    @Test func skipsInsertWhenLastMessageIsFromAgent() async throws {
        let msgRepo = MockMessageRepository()
        let chatRepo = MockChatRepository()
        let chat = makeChat()
        chatRepo.chats = [chat]
        // last message is agent — gap of user messages = 0
        msgRepo.messagesByChat[chat.id] = [
            Message(id: "m1", chatId: chat.id, text: "Hi", type: .text, file: nil, sender: .user, timestamp: 1000),
            Message(id: "m2", chatId: chat.id, text: "Reply", type: .text, file: nil, sender: .agent, timestamp: 2000)
        ]

        let service = AgentService(
            messageRepository: msgRepo,
            chatRepository: chatRepo,
            delayRange: 0.0...0.0,
            decider: AlwaysReplyDecider()
        )

        service.handleUserMessage(chat: chat)
        try await Task.sleep(for: .milliseconds(200))
        #expect(msgRepo.insertedMessages.isEmpty)
    }

    @Test func updatesChatAfterReply() async throws {
        let msgRepo = MockMessageRepository()
        let chatRepo = MockChatRepository()
        let chat = makeChat()
        chatRepo.chats = [chat]
        seedUserMessage(in: msgRepo, chatId: chat.id)

        let service = AgentService(
            messageRepository: msgRepo,
            chatRepository: chatRepo,
            delayRange: 0.0...0.0,
            decider: AlwaysReplyDecider()
        )
        service.handleUserMessage(chat: chat)
        try await Task.sleep(for: .milliseconds(200))
        #expect(chatRepo.updatedChat?.id == "c1")
        #expect((chatRepo.updatedChat?.lastMessageTimestamp ?? 0) > 0)
    }

    @Test func usesLatestTitleNotStaleSnapshot() async throws {
        let msgRepo = MockMessageRepository()
        let chatRepo = MockChatRepository()
        let chat = makeChat()
        chatRepo.chats = [chat]
        seedUserMessage(in: msgRepo, chatId: chat.id)

        let renamedChat = Chat(id: "c1", title: "Renamed Title", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        try? await chatRepo.update(renamedChat)

        let service = AgentService(
            messageRepository: msgRepo,
            chatRepository: chatRepo,
            delayRange: 0.0...0.0,
            decider: AlwaysReplyDecider()
        )
        service.handleUserMessage(chat: chat)
        try await Task.sleep(for: .milliseconds(200))
        #expect(chatRepo.updatedChat?.title == "Renamed Title")
    }

    @Test func textReplyProducesTextMessage() async throws {
        let msgRepo = MockMessageRepository()
        let chatRepo = MockChatRepository()
        let chat = makeChat()
        chatRepo.chats = [chat]
        seedUserMessage(in: msgRepo, chatId: chat.id)

        let service = AgentService(
            messageRepository: msgRepo,
            chatRepository: chatRepo,
            delayRange: 0.0...0.0,
            decider: AlwaysReplyDecider()
        )
        service.handleUserMessage(chat: chat)
        try await Task.sleep(for: .milliseconds(200))
        let msg = try #require(msgRepo.insertedMessages.first)
        #expect(msg.type == .text)
        #expect(msg.text == "Hello from agent")
    }

    @Test func imageReplyProducesFileMessage() async throws {
        let msgRepo = MockMessageRepository()
        let chatRepo = MockChatRepository()
        let chat = makeChat()
        chatRepo.chats = [chat]
        seedUserMessage(in: msgRepo, chatId: chat.id)

        let service = AgentService(
            messageRepository: msgRepo,
            chatRepository: chatRepo,
            delayRange: 0.0...0.0,
            decider: AlwaysImageDecider()
        )
        service.handleUserMessage(chat: chat)
        try await Task.sleep(for: .milliseconds(200))
        let msg = try #require(msgRepo.insertedMessages.first)
        #expect(msg.type == .file)
        #expect(msg.file != nil)
        #expect(msg.file?.path == "https://picsum.photos/400/300")
    }
}
