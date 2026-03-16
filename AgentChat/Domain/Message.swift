import Foundation

enum MessageType: String, Hashable, Sendable {
    case text
    case file
}

enum Sender: String, Hashable, Sendable {
    case user
    case agent
}

struct FileAttachment: Hashable, Sendable {
    let path: String
    let fileSize: Int64
    let thumbnailPath: String?

    var formattedFileSize: String {
        let kb = Double(fileSize) / 1_024
        let mb = kb / 1_024
        let gb = mb / 1_024

        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.0f KB", kb)
        } else {
            return "\(fileSize) bytes"
        }
    }
}

struct Message: Identifiable, Hashable, Sendable {
    let id: String
    let chatId: String
    let text: String
    let type: MessageType
    let file: FileAttachment?
    let sender: Sender
    let timestamp: Int64

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}
