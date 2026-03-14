import Foundation
@testable import AgentChat

final class MockMessageRepository: MessageRepositoryProtocol, @unchecked Sendable {
    var messagesByChat: [String: [Message]] = [:]
    var insertedMessages: [Message] = []
    var deletedChatIds: [String] = []

    // Continuations to manually push updates in tests
    private var streamContinuations: [String: AsyncStream<[Message]>.Continuation] = [:]

    func fetchMessages(for chatId: String) async throws -> [Message] {
        messagesByChat[chatId] ?? []
    }

    func messageStream(for chatId: String) -> AsyncStream<[Message]> {
        AsyncStream { continuation in
            continuation.yield(messagesByChat[chatId] ?? [])
            streamContinuations[chatId] = continuation
        }
    }

    func insert(_ message: Message) async throws {
        insertedMessages.append(message)
        messagesByChat[message.chatId, default: []].append(message)
        streamContinuations[message.chatId]?.yield(messagesByChat[message.chatId] ?? [])
    }

    func deleteAll(for chatId: String) async throws {
        deletedChatIds.append(chatId)
        messagesByChat[chatId] = nil
        streamContinuations[chatId]?.yield([])
    }
}
