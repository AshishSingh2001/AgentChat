import Foundation
@testable import AgentChat

final class MockChatRepository: ChatRepositoryProtocol, @unchecked Sendable {
    var chats: [Chat] = []
    var createCalled = false
    var updatedChat: Chat?
    var deletedId: String?

    func fetchAll() async throws -> [Chat] { chats }

    func create(_ chat: Chat) async throws {
        createCalled = true
        chats.append(chat)
    }

    func update(_ chat: Chat) async throws {
        updatedChat = chat
        if let i = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[i] = chat
        }
    }

    func delete(id: String) async throws {
        deletedId = id
        chats.removeAll { $0.id == id }
    }
}
