import Foundation
import SwiftData

@ModelActor
final actor SwiftDataChatRepository: ChatRepositoryProtocol {
    func fetchAll() async throws -> [Chat] {
        let descriptor = FetchDescriptor<ChatEntity>(
            sortBy: [SortDescriptor(\.lastMessageTimestamp, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { $0.toChat() }
    }

    func fetch(id: String) async throws -> Chat? {
        let chatId = id
        let predicate = #Predicate<ChatEntity> { $0.id == chatId }
        var descriptor = FetchDescriptor<ChatEntity>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.toChat()
    }

    func create(_ chat: Chat) async throws {
        let entity = ChatEntity.from(chat)
        modelContext.insert(entity)
        try save()
    }

    func update(_ chat: Chat) async throws {
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
