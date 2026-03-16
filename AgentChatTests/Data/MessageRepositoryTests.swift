import Testing
import GRDB
@testable import AgentChat

@MainActor
struct MessageRepositoryTests {

    private struct Repos {
        let chat: GRDBChatRepository
        let message: GRDBMessageRepository
    }

    private func makeRepos() throws -> Repos {
        let db = try AppDatabase.inMemory()
        return Repos(chat: GRDBChatRepository(appDatabase: db),
                     message: GRDBMessageRepository(appDatabase: db))
    }

    /// Helper: insert a minimal parent chat so FK constraint is satisfied.
    private func seedChat(id: String = "chat-001", in repos: Repos) async throws {
        let chat = Chat(id: id, title: "T", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        try await repos.chat.create(chat)
    }

    @Test func fetchMessagesReturnsEmptyForUnknownChatId() async throws {
        let repos = try makeRepos()
        let result = try await repos.message.fetchMessages(for: "unknown-chat", before: nil, limit: 100)
        #expect(result.isEmpty)
    }

    @Test func insertPersistsMessageAndIsQueryable() async throws {
        let repos = try makeRepos()
        try await seedChat(in: repos)
        let message = Message(id: "msg-001", chatId: "chat-001", text: "Hello, world!",
                              type: .text, file: nil, sender: .user, timestamp: 1_703_520_480_000)
        try await repos.message.insert(message)

        let result = try await repos.message.fetchMessages(for: "chat-001", before: nil, limit: 100)
        #expect(result.count == 1)
        #expect(result[0].id == "msg-001")
        #expect(result[0].text == "Hello, world!")
    }

    @Test func fetchMessagesSortsByTimestampAscending() async throws {
        let repos = try makeRepos()
        try await seedChat(in: repos)
        let message1 = Message(id: "msg-001", chatId: "chat-001", text: "First", type: .text, file: nil, sender: .user, timestamp: 1_000_000)
        let message2 = Message(id: "msg-002", chatId: "chat-001", text: "Second", type: .text, file: nil, sender: .agent, timestamp: 2_000_000)
        try await repos.message.insert(message1)
        try await repos.message.insert(message2)

        let result = try await repos.message.fetchMessages(for: "chat-001", before: nil, limit: 100)
        #expect(result.count == 2)
        #expect(result[0].id == "msg-001")
        #expect(result[1].id == "msg-002")
    }

    @Test func insertUpdatesParentChatLastMessage() async throws {
        let repos = try makeRepos()

        let chat = Chat(id: "chat-001", title: "Test Chat", lastMessage: "Initial",
                        lastMessageTimestamp: 1_000_000, createdAt: 1_000_000, updatedAt: 1_000_000)
        try await repos.chat.create(chat)

        let message = Message(id: "msg-001", chatId: "chat-001", text: "New message text",
                              type: .text, file: nil, sender: .user, timestamp: 2_000_000)
        try await repos.message.insert(message)

        let chats = try await repos.chat.fetchAll()
        #expect(chats.count == 1)
        #expect(chats[0].lastMessage == "New message text")
        #expect(chats[0].lastMessageTimestamp == 2_000_000)
        #expect(chats[0].updatedAt == 2_000_000)
    }

    @Test func deleteAllRemovesAllMessagesForChat() async throws {
        let repos = try makeRepos()
        try await seedChat(in: repos)
        try await repos.message.insert(Message(id: "msg-001", chatId: "chat-001", text: "First", type: .text, file: nil, sender: .user, timestamp: 1_000_000))
        try await repos.message.insert(Message(id: "msg-002", chatId: "chat-001", text: "Second", type: .text, file: nil, sender: .agent, timestamp: 2_000_000))

        var result = try await repos.message.fetchMessages(for: "chat-001", before: nil, limit: 100)
        #expect(result.count == 2)

        try await repos.message.deleteAll(for: "chat-001")

        result = try await repos.message.fetchMessages(for: "chat-001", before: nil, limit: 100)
        #expect(result.isEmpty)
    }

    @Test func insertWithMissingParentChatThrowsSendFailed() async throws {
        // GRDB enforces FK constraints — inserting to a non-existent chat throws
        let repos = try makeRepos()
        let message = Message(id: "msg-001", chatId: "nonexistent-chat", text: "Hello",
                              type: .text, file: nil, sender: .user, timestamp: 1_000_000)
        do {
            try await repos.message.insert(message)
            Issue.record("Expected MessageError.sendFailed to be thrown")
        } catch is MessageError {
            // expected
        }
    }

    // MARK: - Pagination

    @Test func fetchMessagesRespectsLimit() async throws {
        let repos = try makeRepos()
        try await seedChat(in: repos)
        for i in 0..<10 {
            try await repos.message.insert(Message(id: "m\(i)", chatId: "chat-001", text: "msg \(i)", type: .text, file: nil, sender: .user, timestamp: Int64(i)))
        }
        let result = try await repos.message.fetchMessages(for: "chat-001", before: nil, limit: 5)
        #expect(result.count == 5)
        #expect(result.first?.timestamp == 5)
        #expect(result.last?.timestamp == 9)
    }

    @Test func fetchMessagesWithBeforeCursorExcludesCursorAndNewer() async throws {
        let repos = try makeRepos()
        try await seedChat(in: repos)
        for i in 0..<10 {
            try await repos.message.insert(Message(id: "m\(i)", chatId: "chat-001", text: "msg \(i)", type: .text, file: nil, sender: .user, timestamp: Int64(i * 1000)))
        }
        let result = try await repos.message.fetchMessages(for: "chat-001", before: 5_000, limit: 100)
        #expect(result.count == 5)
        #expect(result.last?.timestamp == 4_000)
    }

    @Test func fetchMessagesBeforeCursorWithLimitReturnsMostRecent() async throws {
        let repos = try makeRepos()
        try await seedChat(in: repos)
        for i in 0..<10 {
            try await repos.message.insert(Message(id: "m\(i)", chatId: "chat-001", text: "msg \(i)", type: .text, file: nil, sender: .user, timestamp: Int64(i)))
        }
        let result = try await repos.message.fetchMessages(for: "chat-001", before: 8, limit: 3)
        #expect(result.count == 3)
        #expect(result.first?.timestamp == 5)
        #expect(result.last?.timestamp == 7)
    }

    @Test func fetchMessagesReturnsEmptyWhenNoMessagesBeforeCursor() async throws {
        let repos = try makeRepos()
        try await seedChat(in: repos)
        try await repos.message.insert(Message(id: "m1", chatId: "chat-001", text: "hi", type: .text, file: nil, sender: .user, timestamp: 1000))
        let result = try await repos.message.fetchMessages(for: "chat-001", before: 500, limit: 100)
        #expect(result.isEmpty)
    }

    // MARK: - newMessageStream

    @Test func newMessageStreamEmitsSingleInsertedMessage() async throws {
        let repos = try makeRepos()
        try await seedChat(in: repos)

        let stream = repos.message.newMessageStream(for: "chat-001")

        var received: Message?
        let collectTask = Task {
            for await msg in stream {
                received = msg
                break
            }
        }

        try await Task.sleep(for: .milliseconds(50)) // let observation seed
        try await repos.message.insert(Message(id: "m1", chatId: "chat-001", text: "Hello", type: .text, file: nil, sender: .user, timestamp: 1000))
        try await Task.sleep(for: .milliseconds(200))
        collectTask.cancel()

        #expect(received?.id == "m1")
        #expect(received?.text == "Hello")
    }

    @Test func newMessageStreamDoesNotEmitForDifferentChat() async throws {
        let repos = try makeRepos()
        try await seedChat(id: "chat-001", in: repos)
        try await seedChat(id: "chat-002", in: repos)

        let stream = repos.message.newMessageStream(for: "chat-001")

        var received: Message?
        let collectTask = Task {
            for await msg in stream {
                received = msg
                break
            }
        }

        try await Task.sleep(for: .milliseconds(50))
        try await repos.message.insert(Message(id: "m1", chatId: "chat-002", text: "Other chat", type: .text, file: nil, sender: .user, timestamp: 1000))
        try await Task.sleep(for: .milliseconds(200))
        collectTask.cancel()

        #expect(received == nil)
    }
}
