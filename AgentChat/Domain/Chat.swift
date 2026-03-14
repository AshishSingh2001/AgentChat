import Foundation

struct Chat: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let lastMessage: String
    let lastMessageTimestamp: Int64
    let createdAt: Int64
    let updatedAt: Int64

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
