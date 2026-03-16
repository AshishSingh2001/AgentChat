import Foundation
@testable import AgentChat

final class MockChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    var chats: [Chat] = []
    var createCalled = false
    var updatedChat: Chat?
    var deletedId: String?
    var updatedTitleId: String?
    var updatedTitleValue: String?
    var updatedDraftId: String?
    var updatedDraftValue: String?

    var shouldThrowError: Error?
    var errorOnMethod: ErrorMethod = .none

    enum ErrorMethod {
        case none
        case create
        case update
        case delete
        case fetch
    }

    private var streams: [AsyncStream<[Chat]>.Continuation] = []

    func fetchAll() async throws -> [Chat] {
        if let error = shouldThrowError, errorOnMethod == .fetch {
            throw error
        }
        return chats
    }

    func fetch(id: String) async throws -> Chat? {
        if let error = shouldThrowError, errorOnMethod == .fetch {
            throw error
        }
        return chats.first(where: { $0.id == id })
    }

    func chatStream() -> AsyncStream<[Chat]> {
        let (stream, continuation) = AsyncStream<[Chat]>.makeStream()
        streams.append(continuation)
        continuation.yield(chats)
        return stream
    }

    func create(_ chat: Chat) async throws {
        if let error = shouldThrowError, errorOnMethod == .create {
            throw error
        }
        createCalled = true
        chats.append(chat)
        streams.forEach { $0.yield(chats) }
    }

    func update(_ chat: Chat) async throws {
        if let error = shouldThrowError, errorOnMethod == .update {
            throw error
        }
        updatedChat = chat
        if let i = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[i] = chat
        }
        streams.forEach { $0.yield(chats) }
    }

    func updateTitle(id: String, title: String) async throws {
        if let error = shouldThrowError, errorOnMethod == .update {
            throw error
        }
        updatedTitleId = id
        updatedTitleValue = title
        if let i = chats.firstIndex(where: { $0.id == id }) {
            let c = chats[i]
            chats[i] = Chat(id: c.id, title: title, lastMessage: c.lastMessage, lastMessageTimestamp: c.lastMessageTimestamp, createdAt: c.createdAt, updatedAt: c.updatedAt, draftText: c.draftText)
            updatedChat = chats[i]
        }
        streams.forEach { $0.yield(chats) }
    }

    func updateDraft(id: String, draftText: String) async throws {
        if let error = shouldThrowError, errorOnMethod == .update {
            throw error
        }
        updatedDraftId = id
        updatedDraftValue = draftText
        if let i = chats.firstIndex(where: { $0.id == id }) {
            let c = chats[i]
            chats[i] = Chat(id: c.id, title: c.title, lastMessage: c.lastMessage, lastMessageTimestamp: c.lastMessageTimestamp, createdAt: c.createdAt, updatedAt: c.updatedAt, draftText: draftText)
            updatedChat = chats[i]
        }
        streams.forEach { $0.yield(chats) }
    }

    func delete(id: String) async throws {
        if let error = shouldThrowError, errorOnMethod == .delete {
            throw error
        }
        deletedId = id
        chats.removeAll { $0.id == id }
        streams.forEach { $0.yield(chats) }
    }
}
