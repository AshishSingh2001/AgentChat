import Foundation

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
            if draftText.isEmpty {
                UserDefaults.standard.removeObject(forKey: draftKey)
            } else {
                UserDefaults.standard.set(draftText, forKey: draftKey)
            }
        }
    }

    // MARK: - Dependencies
    private let chatRepository: any ChatRepositoryProtocol
    private let messageRepository: any MessageRepositoryProtocol
    private let router: any AppRouterProtocol
    private let sendMessageUseCase: SendMessageUseCase
    private let agentReplyDecider: (Int) -> AgentReplyDecision
    let agentReplyDelayRange: ClosedRange<Double>

    // MARK: - Internal State
    private var userMessageCount = 0
    private var pendingReplyTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    private var draftKey: String { "agentchat.draft.\(chat.id)" }

    // MARK: - Init
    init(
        chat: Chat,
        chatRepository: any ChatRepositoryProtocol,
        messageRepository: any MessageRepositoryProtocol,
        router: any AppRouterProtocol,
        agentReplyDelayRange: ClosedRange<Double> = 1.0...2.0,
        agentReplyDecider: ((Int) -> AgentReplyDecision)? = nil
    ) {
        self.chat = chat
        self.chatRepository = chatRepository
        self.messageRepository = messageRepository
        self.router = router
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

        self.draftText = UserDefaults.standard.string(forKey: "agentchat.draft.\(chat.id)") ?? ""
    }

    // MARK: - Message Loading
    func loadMessages() async {
        messages = (try? await messageRepository.fetchMessages(for: chat.id)) ?? []
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
        chat.title = trimmed
        try? await chatRepository.update(chat)
    }
}
