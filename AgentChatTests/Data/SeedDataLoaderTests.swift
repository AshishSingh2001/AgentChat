import Foundation
import Testing
import SwiftData
@testable import AgentChat

@MainActor
struct SeedDataLoaderTests {

    @Test func loadIfNeededInsertThreeChats() async throws {
        let container = try ModelContainer(
            for: ChatEntity.self, MessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let loader = SeedDataLoader(modelContainer: container)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
        try await loader.loadIfNeeded()

        let context = ModelContext(container)
        let chats = try context.fetch(FetchDescriptor<ChatEntity>())
        #expect(chats.count == 3)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
    }

    @Test func loadIfNeededIsNoOpOnSecondCall() async throws {
        let container = try ModelContainer(
            for: ChatEntity.self, MessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let loader = SeedDataLoader(modelContainer: container)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
        try await loader.loadIfNeeded()

        var context = ModelContext(container)
        var chats = try context.fetch(FetchDescriptor<ChatEntity>())
        #expect(chats.count == 3)

        // Call again without clearing the flag
        try await loader.loadIfNeeded()

        context = ModelContext(container)
        chats = try context.fetch(FetchDescriptor<ChatEntity>())
        #expect(chats.count == 3)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
    }

    @Test func chatOneHasTenMessages() async throws {
        let container = try ModelContainer(
            for: ChatEntity.self, MessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let loader = SeedDataLoader(modelContainer: container)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
        try await loader.loadIfNeeded()

        let context = ModelContext(container)
        let predicate = #Predicate<MessageEntity> { $0.chatId == "chat-001" }
        let descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
        let messages = try context.fetch(descriptor)
        #expect(messages.count == 10)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
    }

    @Test func chatTwoHasSixMessages() async throws {
        let container = try ModelContainer(
            for: ChatEntity.self, MessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let loader = SeedDataLoader(modelContainer: container)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
        try await loader.loadIfNeeded()

        let context = ModelContext(container)
        let predicate = #Predicate<MessageEntity> { $0.chatId == "chat-002" }
        let descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
        let messages = try context.fetch(descriptor)
        #expect(messages.count == 6)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
    }

    @Test func chatThreeHasFiveMessages() async throws {
        let container = try ModelContainer(
            for: ChatEntity.self, MessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let loader = SeedDataLoader(modelContainer: container)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
        try await loader.loadIfNeeded()

        let context = ModelContext(container)
        let predicate = #Predicate<MessageEntity> { $0.chatId == "chat-003" }
        let descriptor = FetchDescriptor<MessageEntity>(predicate: predicate)
        let messages = try context.fetch(descriptor)
        #expect(messages.count == 5)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
    }

    @Test func chatOneLastMessageIsCorrect() async throws {
        let container = try ModelContainer(
            for: ChatEntity.self, MessageEntity.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let loader = SeedDataLoader(modelContainer: container)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
        try await loader.loadIfNeeded()

        let context = ModelContext(container)
        let predicate = #Predicate<ChatEntity> { $0.id == "chat-001" }
        var descriptor = FetchDescriptor<ChatEntity>(predicate: predicate)
        descriptor.fetchLimit = 1
        let chats = try context.fetch(descriptor)
        guard let chat = chats.first else {
            Issue.record("Chat-001 not found")
            return
        }
        #expect(chat.lastMessage == "The second option looks perfect! How do I proceed?")

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
    }
}
