import Foundation
@testable import AgentChat

final class MockMessageRepository: MessageRepositoryProtocol, @unchecked Sendable {
    var messagesByChat: [String: [Message]] = [:]
    var insertedMessages: [Message] = []
    var deletedChatIds: [String] = []

    // Use makeStream so the continuation is available immediately — before the
    // consumer's `for await` loop starts iterating. This prevents dropped yields
    // when insert() is called before the stream Task has begun execution.
    private var streams: [String: (stream: AsyncStream<[Message]>, continuation: AsyncStream<[Message]>.Continuation)] = [:]

    func fetchMessages(for chatId: String) async throws -> [Message] {
        messagesByChat[chatId] ?? []
    }

    func messageStream(for chatId: String) -> AsyncStream<[Message]> {
        if let existing = streams[chatId] {
            return existing.stream
        }
        let (stream, continuation) = AsyncStream<[Message]>.makeStream()
        streams[chatId] = (stream, continuation)
        // Emit current snapshot immediately
        continuation.yield(messagesByChat[chatId] ?? [])
        return stream
    }

    func insert(_ message: Message) async throws {
        insertedMessages.append(message)
        messagesByChat[message.chatId, default: []].append(message)
        // Ensure stream exists for this chatId before yielding
        if streams[message.chatId] == nil {
            _ = messageStream(for: message.chatId)
        }
        streams[message.chatId]?.continuation.yield(messagesByChat[message.chatId] ?? [])
    }

    func deleteAll(for chatId: String) async throws {
        deletedChatIds.append(chatId)
        messagesByChat[chatId] = nil
        if streams[chatId] == nil {
            _ = messageStream(for: chatId)
        }
        streams[chatId]?.continuation.yield([])
    }
}
