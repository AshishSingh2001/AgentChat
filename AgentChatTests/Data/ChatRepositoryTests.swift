import Testing
import SwiftData
@testable import AgentChat

@MainActor
struct ChatRepositoryTests {

    @Test func fetchAllReturnsEmptyWhenNoChats() async throws {
        let container = try ModelContainer(
            for: ChatEntity.self, MessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repo = SwiftDataChatRepository(modelContainer: container)
        let result = try await repo.fetchAll()
        #expect(result.isEmpty)
    }

    @Test func createPersistsChatAndIsQueryable() async throws {
        let container = try ModelContainer(
            for: ChatEntity.self, MessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repo = SwiftDataChatRepository(modelContainer: container)

        let chat = Chat(
            id: "chat-001",
            title: "Test Chat",
            lastMessage: "Hello",
            lastMessageTimestamp: 1_703_520_480_000,
            createdAt: 1_703_520_000_000,
            updatedAt: 1_703_520_480_000
        )
        try await repo.create(chat)

        let result = try await repo.fetchAll()
        #expect(result.count == 1)
        #expect(result[0].id == "chat-001")
        #expect(result[0].title == "Test Chat")
    }

    @Test func fetchAllSortsByLastMessageTimestampDescending() async throws {
        let container = try ModelContainer(
            for: ChatEntity.self, MessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repo = SwiftDataChatRepository(modelContainer: container)

        let chat1 = Chat(
            id: "chat-001",
            title: "First Chat",
            lastMessage: "Old",
            lastMessageTimestamp: 1_000_000,
            createdAt: 1_000_000,
            updatedAt: 1_000_000
        )
        let chat2 = Chat(
            id: "chat-002",
            title: "Second Chat",
            lastMessage: "Recent",
            lastMessageTimestamp: 2_000_000,
            createdAt: 1_000_000,
            updatedAt: 2_000_000
        )

        try await repo.create(chat1)
        try await repo.create(chat2)

        let result = try await repo.fetchAll()
        #expect(result.count == 2)
        #expect(result[0].id == "chat-002")  // Most recent first
        #expect(result[1].id == "chat-001")
    }

    @Test func updateMutatesExistingChat() async throws {
        let container = try ModelContainer(
            for: ChatEntity.self, MessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repo = SwiftDataChatRepository(modelContainer: container)

        let chat = Chat(
            id: "chat-001",
            title: "Original Title",
            lastMessage: "Original",
            lastMessageTimestamp: 1_000_000,
            createdAt: 1_000_000,
            updatedAt: 1_000_000
        )
        try await repo.create(chat)

        let updated = Chat(
            id: "chat-001",
            title: "Updated Title",
            lastMessage: "Updated",
            lastMessageTimestamp: 2_000_000,
            createdAt: 1_000_000,
            updatedAt: 2_000_000
        )
        try await repo.update(updated)

        let result = try await repo.fetchAll()
        #expect(result.count == 1)
        #expect(result[0].title == "Updated Title")
        #expect(result[0].lastMessage == "Updated")
    }

    @Test func deleteByChatIdRemovesChat() async throws {
        let container = try ModelContainer(
            for: ChatEntity.self, MessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repo = SwiftDataChatRepository(modelContainer: container)

        let chat = Chat(
            id: "chat-001",
            title: "Test Chat",
            lastMessage: "Hello",
            lastMessageTimestamp: 1_703_520_480_000,
            createdAt: 1_703_520_000_000,
            updatedAt: 1_703_520_480_000
        )
        try await repo.create(chat)

        var result = try await repo.fetchAll()
        #expect(result.count == 1)

        try await repo.delete(id: "chat-001")

        result = try await repo.fetchAll()
        #expect(result.isEmpty)
    }
}
