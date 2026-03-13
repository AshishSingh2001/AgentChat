import Testing
import SwiftData
@testable import AgentChat

@MainActor
struct MessageRepositoryTests {

    @Test func fetchMessagesReturnsEmptyForUnknownChatId() async throws {
        let container = try ModelContainer(
            for: ChatEntity.self, MessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repo = SwiftDataMessageRepository(modelContainer: container)

        let result = try await repo.fetchMessages(for: "unknown-chat")
        #expect(result.isEmpty)
    }

    @Test func insertPersistsMessageAndIsQueryable() async throws {
        let container = try ModelContainer(
            for: ChatEntity.self, MessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repo = SwiftDataMessageRepository(modelContainer: container)

        let message = Message(
            id: "msg-001",
            chatId: "chat-001",
            text: "Hello, world!",
            type: .text,
            file: nil,
            sender: .user,
            timestamp: 1_703_520_480_000
        )
        try await repo.insert(message)

        let result = try await repo.fetchMessages(for: "chat-001")
        #expect(result.count == 1)
        #expect(result[0].id == "msg-001")
        #expect(result[0].text == "Hello, world!")
    }

    @Test func fetchMessagesSortsByTimestampAscending() async throws {
        let container = try ModelContainer(
            for: ChatEntity.self, MessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repo = SwiftDataMessageRepository(modelContainer: container)

        let message1 = Message(
            id: "msg-001",
            chatId: "chat-001",
            text: "First",
            type: .text,
            file: nil,
            sender: .user,
            timestamp: 1_000_000
        )
        let message2 = Message(
            id: "msg-002",
            chatId: "chat-001",
            text: "Second",
            type: .text,
            file: nil,
            sender: .agent,
            timestamp: 2_000_000
        )

        try await repo.insert(message1)
        try await repo.insert(message2)

        let result = try await repo.fetchMessages(for: "chat-001")
        #expect(result.count == 2)
        #expect(result[0].id == "msg-001")
        #expect(result[1].id == "msg-002")
    }

    @Test func insertUpdatesParentChatLastMessage() async throws {
        let container = try ModelContainer(
            for: ChatEntity.self, MessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let chatRepo = SwiftDataChatRepository(modelContainer: container)
        let messageRepo = SwiftDataMessageRepository(modelContainer: container)

        // Create a chat directly
        let chat = Chat(
            id: "chat-001",
            title: "Test Chat",
            lastMessage: "Initial",
            lastMessageTimestamp: 1_000_000,
            createdAt: 1_000_000,
            updatedAt: 1_000_000
        )
        try await chatRepo.create(chat)

        // Insert a message
        let message = Message(
            id: "msg-001",
            chatId: "chat-001",
            text: "New message text",
            type: .text,
            file: nil,
            sender: .user,
            timestamp: 2_000_000
        )
        try await messageRepo.insert(message)

        // Verify chat was updated
        let chats = try await chatRepo.fetchAll()
        #expect(chats.count == 1)
        #expect(chats[0].lastMessage == "New message text")
        #expect(chats[0].lastMessageTimestamp == 2_000_000)
        #expect(chats[0].updatedAt == 2_000_000)
    }

    @Test func deleteAllRemovesAllMessagesForChat() async throws {
        let container = try ModelContainer(
            for: ChatEntity.self, MessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repo = SwiftDataMessageRepository(modelContainer: container)

        let message1 = Message(
            id: "msg-001",
            chatId: "chat-001",
            text: "First",
            type: .text,
            file: nil,
            sender: .user,
            timestamp: 1_000_000
        )
        let message2 = Message(
            id: "msg-002",
            chatId: "chat-001",
            text: "Second",
            type: .text,
            file: nil,
            sender: .agent,
            timestamp: 2_000_000
        )

        try await repo.insert(message1)
        try await repo.insert(message2)

        var result = try await repo.fetchMessages(for: "chat-001")
        #expect(result.count == 2)

        try await repo.deleteAll(for: "chat-001")

        result = try await repo.fetchMessages(for: "chat-001")
        #expect(result.isEmpty)
    }
}
