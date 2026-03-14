import Foundation
import SwiftData

final actor SwiftDataMessageRepository: MessageRepositoryProtocol {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let initializer: DatabaseInitializer

    init(modelContainer: ModelContainer, initializer: DatabaseInitializer) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        self.initializer = initializer
    }

    func fetchMessages(for chatId: String) async throws -> [Message] {
        await initializer.waitForInit()
        return try _fetchMessages(for: chatId)
    }

    func messageStream(for chatId: String) -> AsyncStream<[Message]> {
        AsyncStream { continuation in
            // Emit current snapshot immediately
            let initial = (try? self._fetchMessages(for: chatId)) ?? []
            continuation.yield(initial)

            let task = Task {
                for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave) {
                    guard !Task.isCancelled else { break }
                    let messages = (try? self._fetchMessages(for: chatId)) ?? []
                    continuation.yield(messages)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // Synchronous fetch — caller must ensure waitForInit() has already resolved.
    private func _fetchMessages(for chatId: String) throws -> [Message] {
        let targetChatId = chatId
        let predicate = #Predicate<MessageEntity> { $0.chatId == targetChatId }
        let descriptor = FetchDescriptor<MessageEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map { $0.toMessage() }
    }

    func insert(_ message: Message) async throws {
        await initializer.waitForInit()
        let entity = MessageEntity.from(message)
        modelContext.insert(entity)

        let targetChatId = message.chatId
        let chatPredicate = #Predicate<ChatEntity> { $0.id == targetChatId }
        var chatDescriptor = FetchDescriptor<ChatEntity>(predicate: chatPredicate)
        chatDescriptor.fetchLimit = 1
        if let chatEntity = try modelContext.fetch(chatDescriptor).first {
            chatEntity.lastMessage = message.text
            chatEntity.lastMessageTimestamp = message.timestamp
            chatEntity.updatedAt = message.timestamp
        }

        try save()
    }

    func deleteAll(for chatId: String) async throws {
        await initializer.waitForInit()
        let targetChatId = chatId
        let predicate = #Predicate<MessageEntity> { $0.chatId == targetChatId }
        let descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
        let entities = try modelContext.fetch(descriptor)
        for entity in entities {
            modelContext.delete(entity)
        }
        try save()
    }

    private func save() throws {
        try modelContext.save()
    }
}
