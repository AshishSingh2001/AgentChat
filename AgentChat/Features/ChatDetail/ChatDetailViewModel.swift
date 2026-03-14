import Foundation
import UIKit

@Observable
@MainActor
final class ChatDetailViewModel {
    // MARK: - Published State
    var messages: [Message] = []
    var chat: Chat
    var isTitleEditing = false
    var shouldScrollToBottom = false
    var showNewMessageToast = false
    var isNearBottom = true
    var draftText: String = "" {
        didSet {
            saveDraftText()
        }
    }
    var selectedImageForViewer: ImageViewerItem?
    var pendingAttachment: PendingAttachment?

    // MARK: - Dependencies
    private let chatRepository: any ChatRepositoryProtocol
    private let messageRepository: any MessageRepositoryProtocol
    private let router: any AppRouterProtocol
    private let sendMessageUseCase: SendMessageUseCase
    private let agentReplyDecider: (Int) -> AgentReplyDecision
    let agentReplyDelayRange: ClosedRange<Double>
    let fileStorageService: FileStorageService

    // MARK: - Internal State
    private let chatId: String
    private var userMessageCount = 0
    private var pendingReplyTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

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
        fileStorageService: FileStorageService = FileStorageService(),
        agentReplyDelayRange: ClosedRange<Double> = 1.0...2.0,
        agentReplyDecider: ((Int) -> AgentReplyDecision)? = nil
    ) {
        self.chatId = chatId
        self.chat = Chat(id: chatId, title: "", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        self.chatRepository = chatRepository
        self.messageRepository = messageRepository
        self.router = router
        self.fileStorageService = fileStorageService
        self.agentReplyDelayRange = agentReplyDelayRange
        self.sendMessageUseCase = SendMessageUseCase(
            chatRepository: chatRepository,
            messageRepository: messageRepository
        )

        let useCase = SimulateAgentReplyUseCase()
        var rng = SystemRandomNumberGenerator()
        self.agentReplyDecider = agentReplyDecider ?? { count in
            useCase.decide(userMessageCount: count, using: &rng)
        }

        loadDraftText()
    }

    // MARK: - Message Loading
    func loadMessages() async {
        async let chatTask = chatRepository.fetch(id: chatId)
        async let messagesTask = messageRepository.fetchMessages(for: chatId)
        
        if let loadedChat = try? await chatTask {
            chat = loadedChat
        }
        messages = (try? await messagesTask) ?? []
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

    // MARK: - Sending
    func sendMessage(text: String, file: FileAttachment? = nil) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty || file != nil else { return }

        guard let (message, updatedChat) = try? await sendMessageUseCase.execute(
            text: trimmed,
            file: file,
            chat: chat,
            existingMessageCount: messages.count
        ) else { return }

        chat = updatedChat
        messages.append(message)
        userMessageCount += 1

        draftText = ""
        handleNewMessage()
        scheduleAgentReply(for: userMessageCount)
    }

    // MARK: - Agent Reply
    private func scheduleAgentReply(for count: Int) {
        pendingReplyTask?.cancel()
        pendingReplyTask = Task {
            let delay = Double.random(in: agentReplyDelayRange)
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }

            let decision = agentReplyDecider(count)
            guard decision.shouldReply else { return }

            let now = Int64(Date().timeIntervalSince1970 * 1000)
            let agentMessage: Message

            switch decision.replyType {
            case .text(let content):
                agentMessage = Message(
                    id: UUID().uuidString,
                    chatId: chat.id,
                    text: content,
                    type: .text,
                    file: nil,
                    sender: .agent,
                    timestamp: now
                )
            case .image(let urlString):
                agentMessage = Message(
                    id: UUID().uuidString,
                    chatId: chat.id,
                    text: "",
                    type: .file,
                    file: FileAttachment(path: urlString, fileSize: 0, thumbnailPath: nil),
                    sender: .agent,
                    timestamp: now
                )
            }

            try? await messageRepository.insert(agentMessage)
            messages.append(agentMessage)

            let agentPreview: String
            switch decision.replyType {
            case .text(let content): agentPreview = content
            case .image: agentPreview = "Sent an image"
            }
            let updatedChat = Chat(
                id: chat.id,
                title: chat.title,
                lastMessage: agentPreview,
                lastMessageTimestamp: now,
                createdAt: chat.createdAt,
                updatedAt: now
            )
            try? await chatRepository.update(updatedChat)
            chat = updatedChat

            handleNewMessage()
        }
    }

    // MARK: - Scroll
    func updateScrollOffset(_ offsetFromBottom: CGFloat) {
        isNearBottom = offsetFromBottom < 150
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
            try? await Task.sleep(for: .seconds(3))
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

        let filename = UUID().uuidString + ".jpg"
        guard let savedPath = try? fileStorageService.save(data: attachment.data, filename: filename) else { return }

        let thumbnailData = try? fileStorageService.generateThumbnail(from: attachment.data, maxWidth: 150)
        var thumbnailPath: String? = nil
        if let thumbData = thumbnailData {
            thumbnailPath = try? fileStorageService.save(data: thumbData, filename: "thumb_" + filename)
        }

        let fileAttachment = FileAttachment(
            path: savedPath,
            fileSize: Int64(attachment.data.count),
            thumbnailPath: thumbnailPath
        )
        await sendMessage(text: draftText, file: fileAttachment)
    }
}

struct PendingAttachment {
    let data: Data
    let previewImage: UIImage
}
