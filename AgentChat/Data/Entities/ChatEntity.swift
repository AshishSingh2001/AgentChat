import Foundation
import SwiftData

@Model final class ChatEntity {
    var id: String
    var title: String
    var lastMessage: String
    var lastMessageTimestamp: Int64
    var createdAt: Int64
    var updatedAt: Int64

    @Relationship(deleteRule: .cascade, inverse: \MessageEntity.chat)
    var messages: [MessageEntity] = []

    init(
        id: String,
        title: String,
        lastMessage: String,
        lastMessageTimestamp: Int64,
        createdAt: Int64,
        updatedAt: Int64
    ) {
        self.id = id
        self.title = title
        self.lastMessage = lastMessage
        self.lastMessageTimestamp = lastMessageTimestamp
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = []
    }

    func toChat() -> Chat {
        Chat(
            id: id,
            title: title,
            lastMessage: lastMessage,
            lastMessageTimestamp: lastMessageTimestamp,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static func from(_ chat: Chat) -> ChatEntity {
        ChatEntity(
            id: chat.id,
            title: chat.title,
            lastMessage: chat.lastMessage,
            lastMessageTimestamp: chat.lastMessageTimestamp,
            createdAt: chat.createdAt,
            updatedAt: chat.updatedAt
        )
    }
}
