import Foundation
import SwiftData

@Model final class MessageEntity {
    var id: String
    var chatId: String
    var text: String
    var type: String
    var filePath: String?
    var fileSize: Int64?
    var thumbnailPath: String?
    var sender: String
    var timestamp: Int64

    var chat: ChatEntity?

    init(
        id: String,
        chatId: String,
        text: String,
        type: String,
        filePath: String? = nil,
        fileSize: Int64? = nil,
        thumbnailPath: String? = nil,
        sender: String,
        timestamp: Int64
    ) {
        self.id = id
        self.chatId = chatId
        self.text = text
        self.type = type
        self.filePath = filePath
        self.fileSize = fileSize
        self.thumbnailPath = thumbnailPath
        self.sender = sender
        self.timestamp = timestamp
        self.chat = nil
    }

    func toMessage() -> Message {
        let messageType = MessageType(rawValue: type) ?? .text
        let senderEnum = Sender(rawValue: sender) ?? .user

        let fileAttachment: FileAttachment? = {
            guard let filePath = filePath else { return nil }
            return FileAttachment(
                path: filePath,
                fileSize: fileSize ?? 0,
                thumbnailPath: thumbnailPath
            )
        }()

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

    static func from(_ message: Message) -> MessageEntity {
        let messageEntity = MessageEntity(
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
        return messageEntity
    }
}
