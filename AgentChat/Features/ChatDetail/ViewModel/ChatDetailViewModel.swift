import Foundation
import SwiftUI

@Observable
@MainActor
final class ChatDetailViewModel {
    // MARK: - Sub-VMs
    let messages = MessageListViewModel()
    let draft = DraftViewModel()
    let title: TitleViewModel
    let imageViewer = ImageViewerViewModel()
    let scroll = MessageScrollCoordinator()

    // MARK: - Coordinator State
    var errorMessage: String?


    // MARK: - Dependencies
    private let chat: Chat
    private let chatRepository: any ChatRepositoryProtocol
    private let messageRepository: any MessageRepositoryProtocol
    private let router: any AppRouterProtocol
    private let sendMessageUseCase: SendMessageUseCase
    private let agentService: any AgentServiceProtocol

    private var pendingPaginationTask: Task<Void, Never>?

    // MARK: - Init
    init(
        chat: Chat,
        chatRepository: any ChatRepositoryProtocol,
        messageRepository: any MessageRepositoryProtocol,
        router: any AppRouterProtocol,
        agentService: any AgentServiceProtocol
    ) {
        self.chat = chat
        self.chatRepository = chatRepository
        self.messageRepository = messageRepository
        self.router = router
        self.agentService = agentService
        self.sendMessageUseCase = SendMessageUseCase(
            chatRepository: chatRepository,
            messageRepository: messageRepository
        )
        self.title = TitleViewModel(chat: chat)
        self.draft.text = chat.draftText
        self.draft.configure(chat: chat, repository: chatRepository)
    }
    
    // MARK: - Loading
    func loadMessages() async {
        messages.onNewMessage = { [weak self] msg in
            self?.scroll.handleNewMessage(from: msg.sender, type: msg.type)
        }

        await messages.load(chatId: chat.id, repository: messageRepository)
    }

    func loadOlderMessages() {
        pendingPaginationTask?.cancel()
        pendingPaginationTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await messages.loadOlderMessages(chatId: chat.id, repository: messageRepository)
        }
    }

    // MARK: - Sending
    func sendMessage(text: String, file: FileAttachment? = nil) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty || file != nil else { return }

        do {
            let (sentMessage, updatedChat) = try await sendMessageUseCase.execute(
                text: trimmed,
                file: file,
                chat: title.chat,
                isFirstMessage: messages.messages.isEmpty
            )
            messages.appendIfAbsent(sentMessage)
            title.chat = updatedChat
            draft.configure(chat: updatedChat, repository: chatRepository)
            draft.text = ""
            draft.cancelPendingSave()
            triggerAgentReply()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func triggerAgentReply() {
        agentService.handleUserMessage(chat: title.chat)
    }

    // MARK: - Title Editing
    func commitTitleEdit(newTitle: String) async {
        do {
            try await title.commitEdit(newTitle: newTitle, repository: chatRepository)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Cleanup
    func cleanUpIfEmpty() {
        guard messages.messages.isEmpty && draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task {
            try? await chatRepository.delete(id: chat.id)
        }
    }

    func saveDraftImmediately() {
        draft.saveImmediately()
    }

    // MARK: - Error
    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Image Viewer (forwarding)
    func openImageViewer(url: URL) {
        imageViewer.open(url: url)
    }

    func dismissImageViewer() {
        imageViewer.dismiss()
    }

    // MARK: - Binding Helper
    func binding<Value>(
        for keyPath: ReferenceWritableKeyPath<ChatDetailViewModel, Value>,
        setter: ((Value) -> Void)? = nil
    ) -> Binding<Value> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: { value in
                if let setter {
                    setter(value)
                } else {
                    self[keyPath: keyPath] = value
                }
            }
        )
    }
}
