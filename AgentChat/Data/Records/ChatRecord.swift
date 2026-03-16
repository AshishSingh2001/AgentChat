import Foundation
import GRDB

struct ChatRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "chats"

    var id: String
    var title: String
    var lastMessage: String
    var lastMessageTimestamp: Int64
    var createdAt: Int64
    var updatedAt: Int64
    var draftText: String

    func toChat() -> Chat {
        Chat(
            id: id,
            title: title,
            lastMessage: lastMessage,
            lastMessageTimestamp: lastMessageTimestamp,
            createdAt: createdAt,
            updatedAt: updatedAt,
            draftText: draftText
        )
    }

    static func from(_ chat: Chat) -> ChatRecord {
        ChatRecord(
            id: chat.id,
            title: chat.title,
            lastMessage: chat.lastMessage,
            lastMessageTimestamp: chat.lastMessageTimestamp,
            createdAt: chat.createdAt,
            updatedAt: chat.updatedAt,
            draftText: chat.draftText
        )
    }
}
