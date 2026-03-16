import Foundation
import GRDB

struct MessageRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "messages"

    var id: String
    var chatId: String
    var text: String
    var type: String
    var filePath: String?
    var fileSize: Int64?
    var thumbnailPath: String?
    var sender: String
    var timestamp: Int64

    func toMessage() -> Message {
        let messageType = MessageType(rawValue: type) ?? .text
        let senderEnum = Sender(rawValue: sender) ?? .user
        let fileAttachment: FileAttachment? = filePath.map { path in
            FileAttachment(path: path, fileSize: fileSize ?? 0, thumbnailPath: thumbnailPath)
        }
        return Message(
            id: id,
            chatId: chatId,
            text: text,
            type: messageType,
            file: fileAttachment,
            sender: senderEnum,
            timestamp: timestamp
        )
    }

    static func from(_ message: Message) -> MessageRecord {
        MessageRecord(
            id: message.id,
            chatId: message.chatId,
            text: message.text,
            type: message.type.rawValue,
            filePath: message.file?.path,
            fileSize: message.file?.fileSize,
            thumbnailPath: message.file?.thumbnailPath,
            sender: message.sender.rawValue,
            timestamp: message.timestamp
        )
    }
}
