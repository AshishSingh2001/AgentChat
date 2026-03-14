import Foundation
import SwiftData

final actor SwiftDataChatRepository: ChatRepositoryProtocol {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let initializer: DatabaseInitializer

    init(modelContainer: ModelContainer, initializer: DatabaseInitializer) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        self.initializer = initializer
    }

    func chatStream() -> AsyncStream<[Chat]> {
        AsyncStream { continuation in
            let task = Task {
                await initializer.waitForInit()
                let initial = (try? self._fetchAll()) ?? []
                continuation.yield(initial)

                let context = self.modelContext
                for await notification in NotificationCenter.default.notifications(named: ModelContext.didSave) {
                    guard !Task.isCancelled else { break }
                    guard (notification.object as? ModelContext) === context else { continue }
                    let chats = (try? self._fetchAll()) ?? []
                    continuation.yield(chats)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func fetchAll() async throws -> [Chat] {
        await initializer.waitForInit()
        return try _fetchAll()
    }

    private func _fetchAll() throws -> [Chat] {
        let descriptor = FetchDescriptor<ChatEntity>(
            sortBy: [SortDescriptor(\.lastMessageTimestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map { $0.toChat() }
    }

    func fetch(id: String) async throws -> Chat? {
        await initializer.waitForInit()
        let chatId = id
        let predicate = #Predicate<ChatEntity> { $0.id == chatId }
        var descriptor = FetchDescriptor<ChatEntity>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.toChat()
    }

    func create(_ chat: Chat) async throws {
        await initializer.waitForInit()
        let entity = ChatEntity.from(chat)
        modelContext.insert(entity)
        try save()
    }

    func update(_ chat: Chat) async throws {
        await initializer.waitForInit()
        let chatId = chat.id
        let predicate = #Predicate<ChatEntity> { $0.id == chatId }
        var descriptor = FetchDescriptor<ChatEntity>(predicate: predicate)
        descriptor.fetchLimit = 1
        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        entity.title = chat.title
        entity.lastMessage = chat.lastMessage
        entity.lastMessageTimestamp = chat.lastMessageTimestamp
        entity.updatedAt = chat.updatedAt
        try save()
    }

    func delete(id: String) async throws {
        await initializer.waitForInit()
        let chatId = id
        let predicate = #Predicate<ChatEntity> { $0.id == chatId }
        var descriptor = FetchDescriptor<ChatEntity>(predicate: predicate)
        descriptor.fetchLimit = 1
        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }
        modelContext.delete(entity)
        try save()
    }

    private func save() throws {
        try modelContext.save()
    }
}

enum RepositoryError: Error {
    case notFound
}
