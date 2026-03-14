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
        isFirstMessage: Bool
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

        let newTitle = (isFirstMessage && !trimmed.isEmpty)
            ? String(trimmed.prefix(30))
            : chat.title
        let newLastMessage = (file != nil && trimmed.isEmpty) ? "Attachment" : trimmed

        let updatedChat = Chat(
            id: chat.id,
            title: newTitle,
            lastMessage: newLastMessage,
            lastMessageTimestamp: now,
            createdAt: chat.createdAt,
            updatedAt: now
        )

        try await chatRepository.update(updatedChat)
        return (message, updatedChat)
    }
}

enum SendMessageError: Error, Equatable {
    case emptyMessage
}
