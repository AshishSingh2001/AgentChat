import Foundation
import Testing
import GRDB
@testable import AgentChat

@MainActor
struct SeedDataLoaderTests {

    private func makeDB() throws -> AppDatabase {
        try AppDatabase.inMemory()
    }

    @Test func loadIfNeededInsertThreeChats() throws {
        let db = try makeDB()
        let loader = SeedDataLoader(appDatabase: db)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
        try loader.loadIfNeeded()

        let chats = try db.dbQueue.read { try ChatRecord.fetchAll($0) }
        #expect(chats.count == 3)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
    }

    @Test func loadIfNeededIsNoOpOnSecondCall() throws {
        let db = try makeDB()
        let loader = SeedDataLoader(appDatabase: db)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
        try loader.loadIfNeeded()

        var chats = try db.dbQueue.read { try ChatRecord.fetchAll($0) }
        #expect(chats.count == 3)

        // Call again without clearing the flag — should be a no-op
        try loader.loadIfNeeded()

        chats = try db.dbQueue.read { try ChatRecord.fetchAll($0) }
        #expect(chats.count == 3)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
    }

    @Test func chatOneHasTenMessages() throws {
        let db = try makeDB()
        let loader = SeedDataLoader(appDatabase: db)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
        try loader.loadIfNeeded()

        let messages = try db.dbQueue.read {
            try MessageRecord.filter(Column("chatId") == "chat-001").fetchAll($0)
        }
        #expect(messages.count == 10)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
    }

    @Test func chatTwoHasSixMessages() throws {
        let db = try makeDB()
        let loader = SeedDataLoader(appDatabase: db)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
        try loader.loadIfNeeded()

        let messages = try db.dbQueue.read {
            try MessageRecord.filter(Column("chatId") == "chat-002").fetchAll($0)
        }
        #expect(messages.count == 6)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
    }

    @Test func chatThreeHasFiveMessages() throws {
        let db = try makeDB()
        let loader = SeedDataLoader(appDatabase: db)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
        try loader.loadIfNeeded()

        let messages = try db.dbQueue.read {
            try MessageRecord.filter(Column("chatId") == "chat-003").fetchAll($0)
        }
        #expect(messages.count == 5)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
    }

    @Test func chatOneLastMessageIsCorrect() throws {
        let db = try makeDB()
        let loader = SeedDataLoader(appDatabase: db)

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
        try loader.loadIfNeeded()

        let chat = try db.dbQueue.read { try ChatRecord.fetchOne($0, key: "chat-001") }
        guard let chat else {
            Issue.record("Chat-001 not found")
            return
        }
        #expect(chat.lastMessage == "The second option looks perfect! How do I proceed?")

        UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
    }
}
