import Foundation
import SwiftUI
import UIKit

@Observable
@MainActor
final class ChatDetailViewModel {
    // MARK: - Constants
    private enum Constants {
        static let scrollThreshold: CGFloat = 150
        static let toastDismissDelay: TimeInterval = 3
        static let draftDebounceDelay: Duration = .milliseconds(300)
    }

    // MARK: - Published State
    var messages: [Message] = []
    var chat: Chat
    var isTitleEditing = false
    var shouldScrollToBottom = false
    var showNewMessageToast = false
    var isNearBottom = true
    var draftText: String = "" {
        didSet {
            debouncedSaveDraft()
        }
    }
    var selectedImageForViewer: ImageViewerItem?
    var pendingAttachment: PendingAttachment?

    // MARK: - Dependencies
    private let chatRepository: any ChatRepositoryProtocol
    private let messageRepository: any MessageRepositoryProtocol
    private let router: any AppRouterProtocol
    private let sendMessageUseCase: SendMessageUseCase
    private let sendAttachmentMessageUseCase: SendAttachmentMessageUseCase
    private let agentService: any AgentServiceProtocol
    let fileStorageService: any FileStorageServiceProtocol

    // MARK: - Internal State
    private let chatId: String
    private var userMessageCount = 0
    private var pendingAgentTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var draftSaveTask: Task<Void, Never>?
    private var streamTask: Task<Void, Never>?

    var displayTitle: String {
        chat.title.isEmpty ? "New Chat" : chat.title
    }

    private var draftKey: String { "agentchat.draft.\(chatId)" }

    // MARK: - Init
    init(
        chatId: String,
        chatRepository: any ChatRepositoryProtocol,
        messageRepository: any MessageRepositoryProtocol,
        router: any AppRouterProtocol,
        fileStorageService: any FileStorageServiceProtocol,
        agentService: any AgentServiceProtocol
    ) {
        self.chatId = chatId
        self.chat = Chat(id: chatId, title: "", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        self.chatRepository = chatRepository
        self.messageRepository = messageRepository
        self.router = router
        self.fileStorageService = fileStorageService
        self.agentService = agentService
        self.sendMessageUseCase = SendMessageUseCase(
            chatRepository: chatRepository,
            messageRepository: messageRepository
        )
        self.sendAttachmentMessageUseCase = SendAttachmentMessageUseCase(
            fileStorageService: fileStorageService,
            sendMessageUseCase: self.sendMessageUseCase
        )
        loadDraftText()
    }

    // MARK: - Message Loading
    func loadMessages() async {
        if let loadedChat = try? await chatRepository.fetch(id: chatId) {
            chat = loadedChat
        }

        // Fully reactive: stream is the single source of truth for messages[].
        // Never append optimistically — wait for stream emission after each DB write.
        streamTask?.cancel()
        streamTask = Task {
            for await updated in messageRepository.messageStream(for: chatId) {
                guard !Task.isCancelled else { break }
                let isNewMessage = updated.count > messages.count
                messages = updated
                if isNewMessage {
                    handleNewMessage()
                }
            }
        }
    }

    func loadDraftText() {
        draftText = UserDefaults.standard.string(forKey: draftKey) ?? ""
    }

    private func saveDraftText() {
        if draftText.isEmpty {
            UserDefaults.standard.removeObject(forKey: draftKey)
        } else {
            UserDefaults.standard.set(draftText, forKey: draftKey)
        }
    }

    private func debouncedSaveDraft() {
        draftSaveTask?.cancel()
        draftSaveTask = Task {
            try? await Task.sleep(for: Constants.draftDebounceDelay)
            guard !Task.isCancelled else { return }
            saveDraftText()
        }
    }

    func saveDraftImmediately() {
        draftSaveTask?.cancel()
        saveDraftText()
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

    // MARK: - Sending
    func sendMessage(text: String, file: FileAttachment? = nil) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty || file != nil else { return }

        guard let (_, updatedChat) = try? await sendMessageUseCase.execute(
            text: trimmed,
            file: file,
            chat: chat,
            isFirstMessage: messages.isEmpty
        ) else { return }

        chat = updatedChat
        userMessageCount += 1
        draftText = ""
        triggerAgentReply(for: userMessageCount)
    }

    // MARK: - Agent Reply
    private func triggerAgentReply(for count: Int) {
        pendingAgentTask?.cancel()
        pendingAgentTask = Task {
            await agentService.handleUserMessage(userMessageCount: count, chat: chat)
        }
    }

    // MARK: - Scroll
    func updateScrollOffset(_ offsetFromBottom: CGFloat) {
        isNearBottom = offsetFromBottom < Constants.scrollThreshold
    }

    private func handleNewMessage() {
        if isNearBottom {
            shouldScrollToBottom = true
        } else {
            showNewMessageToast = true
            scheduleToastDismiss()
        }
    }

    // MARK: - Toast
    private func scheduleToastDismiss() {
        toastTask?.cancel()
        toastTask = Task {
            try? await Task.sleep(for: .seconds(Constants.toastDismissDelay))
            guard !Task.isCancelled else { return }
            showNewMessageToast = false
        }
    }

    func dismissToast() {
        toastTask?.cancel()
        toastTask = nil
        showNewMessageToast = false
    }

    // MARK: - Title Editing
    func startTitleEdit() {
        isTitleEditing = true
    }

    func commitTitleEdit(newTitle: String) async {
        let trimmed = newTitle.trimmingCharacters(in: .whitespaces)
        isTitleEditing = false
        guard !trimmed.isEmpty else { return }
        chat = Chat(
            id: chat.id,
            title: trimmed,
            lastMessage: chat.lastMessage,
            lastMessageTimestamp: chat.lastMessageTimestamp,
            createdAt: chat.createdAt,
            updatedAt: chat.updatedAt
        )
        try? await chatRepository.update(chat)
    }

    // MARK: - Image Viewer
    func openImageViewer(for file: FileAttachment) {
        let url: URL?
        if file.path.hasPrefix("http") {
            url = URL(string: file.path)
        } else {
            url = fileStorageService.absoluteURL(for: file.path)
        }
        guard let resolvedURL = url else { return }
        selectedImageForViewer = ImageViewerItem(url: resolvedURL)
    }

    func dismissImageViewer() {
        selectedImageForViewer = nil
    }

    // MARK: - Pending Attachment
    func setPendingAttachment(_ attachment: PendingAttachment) {
        pendingAttachment = attachment
    }

    func clearPendingAttachment() {
        pendingAttachment = nil
    }

    func sendWithAttachment() async {
        guard let attachment = pendingAttachment else { return }
        pendingAttachment = nil

        guard let (_, updatedChat) = try? await sendAttachmentMessageUseCase.execute(
            attachment: attachment,
            text: draftText.trimmingCharacters(in: .whitespaces),
            chat: chat,
            isFirstMessage: messages.isEmpty
        ) else { return }

        chat = updatedChat
        userMessageCount += 1
        draftText = ""
        triggerAgentReply(for: userMessageCount)
    }
}

struct PendingAttachment {
    let data: Data
    let previewImage: UIImage
}
