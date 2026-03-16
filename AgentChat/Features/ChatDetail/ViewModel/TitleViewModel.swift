import Foundation

@Observable
@MainActor
final class TitleViewModel {
    var chat: Chat
    var isTitleEditing = false

    var displayTitle: String {
        chat.title.isEmpty ? "New Chat" : chat.title
    }

    init(chat: Chat) {
        self.chat = chat
    }

    func startEdit() {
        isTitleEditing = true
    }

    func commitEdit(newTitle: String, repository: any ChatRepositoryProtocol) async throws {
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        isTitleEditing = false
        guard !trimmed.isEmpty else { return }
        try await repository.updateTitle(id: chat.id, title: trimmed)
        chat = Chat(
            id: chat.id,
            title: trimmed,
            lastMessage: chat.lastMessage,
            lastMessageTimestamp: chat.lastMessageTimestamp,
            createdAt: chat.createdAt,
            updatedAt: chat.updatedAt,
            draftText: chat.draftText
        )
    }
}
