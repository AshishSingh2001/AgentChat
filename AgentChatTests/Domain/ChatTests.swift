import Testing
@testable import AgentChat

@MainActor
struct ChatTests {

    // MARK: - Initialisation

    @Test func initializesWithProvidedValues() {
        let chat = Chat(
            id: "chat-001",
            title: "Mumbai Flight Booking",
            lastMessage: "The second option looks perfect!",
            lastMessageTimestamp: 1_703_520_480_000,
            createdAt: 1_703_520_000_000,
            updatedAt: 1_703_520_480_000
        )
        #expect(chat.id == "chat-001")
        #expect(chat.title == "Mumbai Flight Booking")
        #expect(chat.lastMessage == "The second option looks perfect!")
        #expect(chat.lastMessageTimestamp == 1_703_520_480_000)
        #expect(chat.createdAt == 1_703_520_000_000)
        #expect(chat.updatedAt == 1_703_520_480_000)
    }

    // MARK: - Equality (all fields)

    @Test func chatsWithIdenticalFieldsAreEqual() {
        let chat1 = Chat(id: "abc", title: "A", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        let chat2 = Chat(id: "abc", title: "A", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        #expect(chat1 == chat2)
    }

    @Test func chatsWithSameIDButDifferentFieldsAreNotEqual() {
        let chat1 = Chat(id: "abc", title: "A", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        let chat2 = Chat(id: "abc", title: "B", lastMessage: "Different", lastMessageTimestamp: 999, createdAt: 0, updatedAt: 0)
        // Synthesized equality compares all fields — different title/lastMessage means not equal
        #expect(chat1 != chat2)
    }

    @Test func chatsWithDifferentIDsAreNotEqual() {
        let chat1 = Chat(id: "abc", title: "A", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        let chat2 = Chat(id: "def", title: "A", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        #expect(chat1 != chat2)
    }

    // MARK: - Hashability (ID-based for Set/Dictionary keying)

    @Test func chatsWithSameIDHashToSameValue() {
        let chat1 = Chat(id: "abc", title: "A", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        let chat2 = Chat(id: "abc", title: "B", lastMessage: "X", lastMessageTimestamp: 999, createdAt: 0, updatedAt: 0)
        #expect(chat1.hashValue == chat2.hashValue)
    }

    // MARK: - Timestamp precision

    @Test func millisecondsStoredWithoutPrecisionLoss() {
        let timestamp: Int64 = 1_703_520_480_999
        let chat = Chat(id: "x", title: "", lastMessage: "", lastMessageTimestamp: timestamp, createdAt: timestamp, updatedAt: timestamp)
        #expect(chat.lastMessageTimestamp == 1_703_520_480_999)
        #expect(chat.createdAt == 1_703_520_480_999)
        #expect(chat.updatedAt == 1_703_520_480_999)
    }

    // MARK: - Sendable (compile-time)

    @Test func chatIsSendableAcrossActorBoundary() async {
        let chat = Chat(id: "x", title: "", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        let captured = await Task.detached { chat }.value
        #expect(captured.id == "x")
    }
}
