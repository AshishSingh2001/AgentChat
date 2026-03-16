import Foundation
import GRDB

struct SeedDataLoader {
    private static let seedKey = "agentchat.seedLoaded"
    private let appDatabase: AppDatabase

    init(appDatabase: AppDatabase) {
        self.appDatabase = appDatabase
    }

    func loadIfNeeded() throws {
        guard !UserDefaults.standard.bool(forKey: Self.seedKey) else { return }
        try insertSeedData()
        UserDefaults.standard.set(true, forKey: Self.seedKey)
    }

    func resetAndReload() throws {
        try appDatabase.dbQueue.write { db in
            try db.execute(sql: "DELETE FROM messages")
            try db.execute(sql: "DELETE FROM chats")
        }
        try insertSeedData()
        UserDefaults.standard.set(true, forKey: Self.seedKey)
    }

    private func insertSeedData() throws {
        try appDatabase.dbQueue.write { db in
            // Chat 1 - Mumbai Flight Booking
            try ChatRecord(
                id: "chat-001",
                title: "Mumbai Flight Booking",
                lastMessage: "The second option looks perfect! How do I proceed?",
                lastMessageTimestamp: 1_703_520_480_000,
                createdAt: 1_703_520_000_000,
                updatedAt: 1_703_520_480_000,
                draftText: ""
            ).insert(db)

            try MessageRecord(id: "msg-001", chatId: "chat-001", text: "Hi! I need help booking a flight to Mumbai.", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "user", timestamp: 1_703_520_000_000).insert(db)
            try MessageRecord(id: "msg-002", chatId: "chat-001", text: "Hello! I'd be happy to help you book a flight to Mumbai. When are you planning to travel?", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "agent", timestamp: 1_703_520_030_000).insert(db)
            try MessageRecord(id: "msg-003", chatId: "chat-001", text: "Next Friday, December 29th.", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "user", timestamp: 1_703_520_090_000).insert(db)
            try MessageRecord(id: "msg-004", chatId: "chat-001", text: "Great! And when would you like to return?", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "agent", timestamp: 1_703_520_120_000).insert(db)
            try MessageRecord(id: "msg-005", chatId: "chat-001", text: "January 5th. Also, I prefer morning flights.", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "user", timestamp: 1_703_520_180_000).insert(db)
            try MessageRecord(id: "msg-006", chatId: "chat-001", text: "Perfect! Let me search for morning flights from your location to Mumbai. Could you also share your departure city?", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "agent", timestamp: 1_703_520_210_000).insert(db)
            try MessageRecord(id: "msg-007", chatId: "chat-001", text: "", type: "file", filePath: "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=400", fileSize: 245_680, thumbnailPath: "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=100", sender: "user", timestamp: 1_703_520_300_000).insert(db)
            try MessageRecord(id: "msg-008", chatId: "chat-001", text: "Thanks for sharing! I can see you prefer IndiGo. Let me find the best options for you.", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "agent", timestamp: 1_703_520_330_000).insert(db)
            try MessageRecord(id: "msg-009", chatId: "chat-001", text: "Flight options comparison", type: "file", filePath: "https://images.unsplash.com/photo-1464037866556-6812c9d1c72e?w=400", fileSize: 189_420, thumbnailPath: "https://images.unsplash.com/photo-1464037866556-6812c9d1c72e?w=100", sender: "agent", timestamp: 1_703_520_420_000).insert(db)
            try MessageRecord(id: "msg-010", chatId: "chat-001", text: "The second option looks perfect! How do I proceed?", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "user", timestamp: 1_703_520_480_000).insert(db)

            // Chat 2 - Hotel Reservation Help
            try ChatRecord(
                id: "chat-002",
                title: "Hotel Reservation Help",
                lastMessage: "I've found 5 hotels in that area. Here's a comparison.",
                lastMessageTimestamp: 1_703_450_000_000,
                createdAt: 1_703_440_000_000,
                updatedAt: 1_703_450_000_000,
                draftText: ""
            ).insert(db)

            try MessageRecord(id: "msg-011", chatId: "chat-002", text: "I need to find a hotel in Bangalore for 3 nights.", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "user", timestamp: 1_703_440_000_000).insert(db)
            try MessageRecord(id: "msg-012", chatId: "chat-002", text: "Sure! What dates and what's your budget range?", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "agent", timestamp: 1_703_440_060_000).insert(db)
            try MessageRecord(id: "msg-013", chatId: "chat-002", text: "Dec 28 to Dec 31. Budget around ₹5000 per night.", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "user", timestamp: 1_703_440_180_000).insert(db)
            try MessageRecord(id: "msg-014", chatId: "chat-002", text: "Got it! Let me search available hotels in Bangalore for those dates.", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "agent", timestamp: 1_703_440_300_000).insert(db)
            try MessageRecord(id: "msg-015", chatId: "chat-002", text: "Prefer something close to MG Road.", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "user", timestamp: 1_703_449_800_000).insert(db)
            try MessageRecord(id: "msg-016", chatId: "chat-002", text: "I've found 5 hotels in that area. Here's a comparison.", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "agent", timestamp: 1_703_450_000_000).insert(db)

            // Chat 3 - Restaurant Recommendations
            try ChatRecord(
                id: "chat-003",
                title: "Restaurant Recommendations",
                lastMessage: "Thanks! I'll check them out.",
                lastMessageTimestamp: 1_703_380_000_000,
                createdAt: 1_703_370_000_000,
                updatedAt: 1_703_380_000_000,
                draftText: ""
            ).insert(db)

            try MessageRecord(id: "msg-017", chatId: "chat-003", text: "Can you recommend good restaurants in Koramangala?", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "user", timestamp: 1_703_370_000_000).insert(db)
            try MessageRecord(id: "msg-018", chatId: "chat-003", text: "Absolutely! Are you looking for any specific cuisine?", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "agent", timestamp: 1_703_370_120_000).insert(db)
            try MessageRecord(id: "msg-019", chatId: "chat-003", text: "Something casual, maybe South Indian or Continental.", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "user", timestamp: 1_703_370_300_000).insert(db)
            try MessageRecord(id: "msg-020", chatId: "chat-003", text: "Here are my top picks: Meghana Foods, Truffles, and Hole in the Wall Cafe.", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "agent", timestamp: 1_703_379_600_000).insert(db)
            try MessageRecord(id: "msg-021", chatId: "chat-003", text: "Thanks! I'll check them out.", type: "text", filePath: nil, fileSize: nil, thumbnailPath: nil, sender: "user", timestamp: 1_703_380_000_000).insert(db)
        }
    }
}
