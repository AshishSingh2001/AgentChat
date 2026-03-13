import Foundation

struct Chat: Identifiable, Hashable, Sendable {
    let id: String
    var title: String
    var lastMessage: String
    var lastMessageTimestamp: Int64
    let createdAt: Int64
    var updatedAt: Int64

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    nonisolated static func == (lhs: Chat, rhs: Chat) -> Bool {
        lhs.id == rhs.id
    }
}
