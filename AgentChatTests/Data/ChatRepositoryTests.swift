import Testing
import GRDB
@testable import AgentChat

@MainActor
struct ChatRepositoryTests {

    private func makeRepo() throws -> GRDBChatRepository {
        let db = try AppDatabase.inMemory()
        return GRDBChatRepository(appDatabase: db)
    }

    @Test func fetchAllReturnsEmptyWhenNoChats() async throws {
        let repo = try makeRepo()
        let result = try await repo.fetchAll()
        #expect(result.isEmpty)
    }

    @Test func createPersistsChatAndIsQueryable() async throws {
        let repo = try makeRepo()

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
        let repo = try makeRepo()

        let chat1 = Chat(id: "chat-001", title: "First Chat", lastMessage: "Old",
                         lastMessageTimestamp: 1_000_000, createdAt: 1_000_000, updatedAt: 1_000_000)
        let chat2 = Chat(id: "chat-002", title: "Second Chat", lastMessage: "Recent",
                         lastMessageTimestamp: 2_000_000, createdAt: 1_000_000, updatedAt: 2_000_000)

        try await repo.create(chat1)
        try await repo.create(chat2)

        let result = try await repo.fetchAll()
        #expect(result.count == 2)
        #expect(result[0].id == "chat-002")
        #expect(result[1].id == "chat-001")
    }

    @Test func updateMutatesExistingChat() async throws {
        let repo = try makeRepo()

        let chat = Chat(id: "chat-001", title: "Original Title", lastMessage: "Original",
                        lastMessageTimestamp: 1_000_000, createdAt: 1_000_000, updatedAt: 1_000_000)
        try await repo.create(chat)

        let updated = Chat(id: "chat-001", title: "Updated Title", lastMessage: "Updated",
                           lastMessageTimestamp: 2_000_000, createdAt: 1_000_000, updatedAt: 2_000_000)
        try await repo.update(updated)

        let result = try await repo.fetchAll()
        #expect(result.count == 1)
        #expect(result[0].title == "Updated Title")
        #expect(result[0].lastMessage == "Updated")
    }

    @Test func deleteByChatIdRemovesChat() async throws {
        let repo = try makeRepo()

        let chat = Chat(id: "chat-001", title: "Test Chat", lastMessage: "Hello",
                        lastMessageTimestamp: 1_703_520_480_000, createdAt: 1_703_520_000_000, updatedAt: 1_703_520_480_000)
        try await repo.create(chat)

        var result = try await repo.fetchAll()
        #expect(result.count == 1)

        try await repo.delete(id: "chat-001")

        result = try await repo.fetchAll()
        #expect(result.isEmpty)
    }

    @Test func updateThrowsChatErrorWhenChatNotFound() async throws {
        let repo = try makeRepo()

        let chat = Chat(id: "nonexistent", title: "Test", lastMessage: "",
                        lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)

        do {
            try await repo.update(chat)
            Issue.record("Expected ChatError.notFound to be thrown")
        } catch let error as ChatError {
            #expect(error == .notFound)
        }
    }

    @Test func deleteThrowsChatErrorWhenChatNotFound() async throws {
        let repo = try makeRepo()

        do {
            try await repo.delete(id: "nonexistent")
            Issue.record("Expected ChatError.notFound to be thrown")
        } catch let error as ChatError {
            #expect(error == .notFound)
        }
    }
}
