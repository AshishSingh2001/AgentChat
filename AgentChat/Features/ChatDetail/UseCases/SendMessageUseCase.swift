import Foundation

struct SendMessageUseCase {
    let chatRepository: any ChatRepositoryProtocol
    let messageRepository: any MessageRepositoryProtocol

    /// Returns (inserted message, updated chat).
    /// Throws `SendMessageError.emptyMessage` if text is empty AND file is nil.
    func execute(
        text: String,
        file: FileAttachment? = nil,
        chat: Chat,
        existingMessageCount: Int
    ) async throws -> (message: Message, updatedChat: Chat) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty || file != nil else {
            throw SendMessageError.emptyMessage
        }

        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let message = Message(
            id: UUID().uuidString,
            chatId: chat.id,
            text: trimmed,
            type: file != nil ? .file : .text,
            file: file,
            sender: .user,
            timestamp: now
        )
        try await messageRepository.insert(message)

        var updatedChat = chat
        updatedChat.lastMessage = (file != nil && trimmed.isEmpty) ? "📎 Attachment" : trimmed
        updatedChat.lastMessageTimestamp = now
        updatedChat.updatedAt = now

        if existingMessageCount == 0 && !trimmed.isEmpty {
            updatedChat.title = String(trimmed.prefix(30))
        }

        try await chatRepository.update(updatedChat)
        return (message, updatedChat)
    }
}

enum SendMessageError: Error, Equatable {
    case emptyMessage
}
