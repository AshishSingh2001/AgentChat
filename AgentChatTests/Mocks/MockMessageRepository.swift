import Foundation
@testable import AgentChat

final class MockMessageRepository: MessageRepositoryProtocol, @unchecked Sendable {
    var messagesByChat: [String: [Message]] = [:]
    var insertedMessages: [Message] = []
    var deletedChatIds: [String] = []

    func fetchMessages(for chatId: String) async throws -> [Message] {
        messagesByChat[chatId] ?? []
    }

    func insert(_ message: Message) async throws {
        insertedMessages.append(message)
        messagesByChat[message.chatId, default: []].append(message)
    }

    func deleteAll(for chatId: String) async throws {
        deletedChatIds.append(chatId)
        messagesByChat[chatId] = nil
    }
}
