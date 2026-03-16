import Foundation

struct Chat: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let lastMessage: String
    let lastMessageTimestamp: Int64
    let createdAt: Int64
    let updatedAt: Int64
    let draftText: String

    nonisolated init(
        id: String,
        title: String,
        lastMessage: String,
        lastMessageTimestamp: Int64,
        createdAt: Int64,
        updatedAt: Int64,
        draftText: String = ""
    ) {
        self.id = id
        self.title = title
        self.lastMessage = lastMessage
        self.lastMessageTimestamp = lastMessageTimestamp
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.draftText = draftText
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
