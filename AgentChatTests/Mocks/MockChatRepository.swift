import Foundation
@testable import AgentChat

final class MockChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    var chats: [Chat] = []
    var createCalled = false
    var updatedChat: Chat?
    var deletedId: String?

    private var streams: [AsyncStream<[Chat]>.Continuation] = []

    func fetchAll() async throws -> [Chat] { chats }

    func fetch(id: String) async throws -> Chat? {
        chats.first(where: { $0.id == id })
    }

    func chatStream() -> AsyncStream<[Chat]> {
        let (stream, continuation) = AsyncStream<[Chat]>.makeStream()
        streams.append(continuation)
        continuation.yield(chats)
        return stream
    }

    func create(_ chat: Chat) async throws {
        createCalled = true
        chats.append(chat)
        streams.forEach { $0.yield(chats) }
    }

    func update(_ chat: Chat) async throws {
        updatedChat = chat
        if let i = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[i] = chat
        }
        streams.forEach { $0.yield(chats) }
    }

    func delete(id: String) async throws {
        deletedId = id
        chats.removeAll { $0.id == id }
        streams.forEach { $0.yield(chats) }
    }
}
