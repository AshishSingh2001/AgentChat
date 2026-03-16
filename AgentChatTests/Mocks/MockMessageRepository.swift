import Foundation
@testable import AgentChat

final class MockMessageRepository: MessageRepositoryProtocol, @unchecked Sendable {
    var messagesByChat: [String: [Message]] = [:]
    var insertedMessages: [Message] = []
    var deletedChatIds: [String] = []

    var shouldThrowError: Error?
    var errorOnMethod: ErrorMethod = .none

    enum ErrorMethod {
        case none
        case insert
        case delete
        case fetch
    }

    private var newMessageStreams: [String: (stream: AsyncStream<Message>, continuation: AsyncStream<Message>.Continuation)] = [:]

    func fetchMessages(for chatId: String, before: Int64?, limit: Int) async throws -> [Message] {
        if let error = shouldThrowError, errorOnMethod == .fetch {
            throw error
        }
        let all = (messagesByChat[chatId] ?? []).sorted { $0.timestamp < $1.timestamp }
        let filtered = before.map { cursor in all.filter { $0.timestamp < cursor } } ?? all
        return Array(filtered.suffix(limit))
    }

    func newMessageStream(for chatId: String) -> AsyncStream<Message> {
        if let existing = newMessageStreams[chatId] {
            return existing.stream
        }
        let (stream, continuation) = AsyncStream<Message>.makeStream()
        newMessageStreams[chatId] = (stream, continuation)
        return stream
    }

    func insert(_ message: Message) async throws {
        if let error = shouldThrowError, errorOnMethod == .insert {
            throw error
        }
        insertedMessages.append(message)
        messagesByChat[message.chatId, default: []].append(message)
        if newMessageStreams[message.chatId] == nil {
            _ = newMessageStream(for: message.chatId)
        }
        newMessageStreams[message.chatId]?.continuation.yield(message)
    }

    func deleteAll(for chatId: String) async throws {
        if let error = shouldThrowError, errorOnMethod == .delete {
            throw error
        }
        deletedChatIds.append(chatId)
        messagesByChat[chatId] = nil
    }

    // Test helper — directly push a message into the stream without going through insert()
    func simulateIncomingMessage(_ message: Message) {
        messagesByChat[message.chatId, default: []].append(message)
        if newMessageStreams[message.chatId] == nil {
            _ = newMessageStream(for: message.chatId)
        }
        newMessageStreams[message.chatId]?.continuation.yield(message)
    }
}
