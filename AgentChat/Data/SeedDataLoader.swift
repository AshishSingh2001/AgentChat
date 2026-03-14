import Foundation
import SwiftData

@ModelActor
final actor SeedDataLoader {
    private static let seedKey = "agentchat.seedLoaded"
    private var hasLoaded = false

    func loadIfNeeded() async throws {
        guard !UserDefaults.standard.bool(forKey: Self.seedKey) && !hasLoaded else { return }
        try await insertSeedData()
        hasLoaded = true
        UserDefaults.standard.set(true, forKey: Self.seedKey)
    }

    func resetAndReload() async throws {
        let allMessages = try modelContext.fetch(FetchDescriptor<MessageEntity>())
        for msg in allMessages { modelContext.delete(msg) }
        let allChats = try modelContext.fetch(FetchDescriptor<ChatEntity>())
        for chat in allChats { modelContext.delete(chat) }
        try modelContext.save()
        try await insertSeedData()
        hasLoaded = true
        UserDefaults.standard.set(true, forKey: Self.seedKey)
    }

    private func insertSeedData() async throws {
        // Chat 1 - Mumbai Flight Booking
        let chat1 = ChatEntity(
            id: "chat-001",
            title: "Mumbai Flight Booking",
            lastMessage: "The second option looks perfect! How do I proceed?",
            lastMessageTimestamp: 1_703_520_480_000,
            createdAt: 1_703_520_000_000,
            updatedAt: 1_703_520_480_000
        )
        modelContext.insert(chat1)

        // Messages for Chat 1
        let msg1 = MessageEntity(
            id: "msg-001",
            chatId: "chat-001",
            text: "Hi! I need help booking a flight to Mumbai.",
            type: "text",
            sender: "user",
            timestamp: 1_703_520_000_000
        )
        msg1.chat = chat1
        modelContext.insert(msg1)

        let msg2 = MessageEntity(
            id: "msg-002",
            chatId: "chat-001",
            text: "Hello! I'd be happy to help you book a flight to Mumbai. When are you planning to travel?",
            type: "text",
            sender: "agent",
            timestamp: 1_703_520_030_000
        )
        msg2.chat = chat1
        modelContext.insert(msg2)

        let msg3 = MessageEntity(
            id: "msg-003",
            chatId: "chat-001",
            text: "Next Friday, December 29th.",
            type: "text",
            sender: "user",
            timestamp: 1_703_520_090_000
        )
        msg3.chat = chat1
        modelContext.insert(msg3)

        let msg4 = MessageEntity(
            id: "msg-004",
            chatId: "chat-001",
            text: "Great! And when would you like to return?",
            type: "text",
            sender: "agent",
            timestamp: 1_703_520_120_000
        )
        msg4.chat = chat1
        modelContext.insert(msg4)

        let msg5 = MessageEntity(
            id: "msg-005",
            chatId: "chat-001",
            text: "January 5th. Also, I prefer morning flights.",
            type: "text",
            sender: "user",
            timestamp: 1_703_520_180_000
        )
        msg5.chat = chat1
        modelContext.insert(msg5)

        let msg6 = MessageEntity(
            id: "msg-006",
            chatId: "chat-001",
            text: "Perfect! Let me search for morning flights from your location to Mumbai. Could you also share your departure city?",
            type: "text",
            sender: "agent",
            timestamp: 1_703_520_210_000
        )
        msg6.chat = chat1
        modelContext.insert(msg6)

        let msg7 = MessageEntity(
            id: "msg-007",
            chatId: "chat-001",
            text: "",
            type: "file",
            filePath: "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=400",
            fileSize: 245_680,
            thumbnailPath: "https://images.unsplash.com/photo-1436491865332-7a61a109cc05?w=100",
            sender: "user",
            timestamp: 1_703_520_300_000
        )
        msg7.chat = chat1
        modelContext.insert(msg7)

        let msg8 = MessageEntity(
            id: "msg-008",
            chatId: "chat-001",
            text: "Thanks for sharing! I can see you prefer IndiGo. Let me find the best options for you.",
            type: "text",
            sender: "agent",
            timestamp: 1_703_520_330_000
        )
        msg8.chat = chat1
        modelContext.insert(msg8)

        let msg9 = MessageEntity(
            id: "msg-009",
            chatId: "chat-001",
            text: "Flight options comparison",
            type: "file",
            filePath: "https://images.unsplash.com/photo-1464037866556-6812c9d1c72e?w=400",
            fileSize: 189_420,
            thumbnailPath: "https://images.unsplash.com/photo-1464037866556-6812c9d1c72e?w=100",
            sender: "agent",
            timestamp: 1_703_520_420_000
        )
        msg9.chat = chat1
        modelContext.insert(msg9)

        let msg10 = MessageEntity(
            id: "msg-010",
            chatId: "chat-001",
            text: "The second option looks perfect! How do I proceed?",
            type: "text",
            sender: "user",
            timestamp: 1_703_520_480_000
        )
        msg10.chat = chat1
        modelContext.insert(msg10)

        // Chat 2 - Hotel Reservation Help
        let chat2 = ChatEntity(
            id: "chat-002",
            title: "Hotel Reservation Help",
            lastMessage: "I've found 5 hotels in that area. Here's a comparison.",
            lastMessageTimestamp: 1_703_450_000_000,
            createdAt: 1_703_440_000_000,
            updatedAt: 1_703_450_000_000
        )
        modelContext.insert(chat2)

        let msg11 = MessageEntity(
            id: "msg-011",
            chatId: "chat-002",
            text: "I need to find a hotel in Bangalore for 3 nights.",
            type: "text",
            sender: "user",
            timestamp: 1_703_440_000_000
        )
        msg11.chat = chat2
        modelContext.insert(msg11)

        let msg12 = MessageEntity(
            id: "msg-012",
            chatId: "chat-002",
            text: "Sure! What dates and what's your budget range?",
            type: "text",
            sender: "agent",
            timestamp: 1_703_440_060_000
        )
        msg12.chat = chat2
        modelContext.insert(msg12)

        let msg13 = MessageEntity(
            id: "msg-013",
            chatId: "chat-002",
            text: "Dec 28 to Dec 31. Budget around ₹5000 per night.",
            type: "text",
            sender: "user",
            timestamp: 1_703_440_180_000
        )
        msg13.chat = chat2
        modelContext.insert(msg13)

        let msg14 = MessageEntity(
            id: "msg-014",
            chatId: "chat-002",
            text: "Got it! Let me search available hotels in Bangalore for those dates.",
            type: "text",
            sender: "agent",
            timestamp: 1_703_440_300_000
        )
        msg14.chat = chat2
        modelContext.insert(msg14)

        let msg15 = MessageEntity(
            id: "msg-015",
            chatId: "chat-002",
            text: "Prefer something close to MG Road.",
            type: "text",
            sender: "user",
            timestamp: 1_703_449_800_000
        )
        msg15.chat = chat2
        modelContext.insert(msg15)

        let msg16 = MessageEntity(
            id: "msg-016",
            chatId: "chat-002",
            text: "I've found 5 hotels in that area. Here's a comparison.",
            type: "text",
            sender: "agent",
            timestamp: 1_703_450_000_000
        )
        msg16.chat = chat2
        modelContext.insert(msg16)

        // Chat 3 - Restaurant Recommendations
        let chat3 = ChatEntity(
            id: "chat-003",
            title: "Restaurant Recommendations",
            lastMessage: "Thanks! I'll check them out.",
            lastMessageTimestamp: 1_703_380_000_000,
            createdAt: 1_703_370_000_000,
            updatedAt: 1_703_380_000_000
        )
        modelContext.insert(chat3)

        let msg17 = MessageEntity(
            id: "msg-017",
            chatId: "chat-003",
            text: "Can you recommend good restaurants in Koramangala?",
            type: "text",
            sender: "user",
            timestamp: 1_703_370_000_000
        )
        msg17.chat = chat3
        modelContext.insert(msg17)

        let msg18 = MessageEntity(
            id: "msg-018",
            chatId: "chat-003",
            text: "Absolutely! Are you looking for any specific cuisine?",
            type: "text",
            sender: "agent",
            timestamp: 1_703_370_120_000
        )
        msg18.chat = chat3
        modelContext.insert(msg18)

        let msg19 = MessageEntity(
            id: "msg-019",
            chatId: "chat-003",
            text: "Something casual, maybe South Indian or Continental.",
            type: "text",
            sender: "user",
            timestamp: 1_703_370_300_000
        )
        msg19.chat = chat3
        modelContext.insert(msg19)

        let msg20 = MessageEntity(
            id: "msg-020",
            chatId: "chat-003",
            text: "Here are my top picks: Meghana Foods, Truffles, and Hole in the Wall Cafe.",
            type: "text",
            sender: "agent",
            timestamp: 1_703_379_600_000
        )
        msg20.chat = chat3
        modelContext.insert(msg20)

        let msg21 = MessageEntity(
            id: "msg-021",
            chatId: "chat-003",
            text: "Thanks! I'll check them out.",
            type: "text",
            sender: "user",
            timestamp: 1_703_380_000_000
        )
        msg21.chat = chat3
        modelContext.insert(msg21)

        try modelContext.save()
    }
}
