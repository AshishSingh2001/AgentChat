import Foundation

actor AgentService: AgentServiceProtocol {
    private let messageRepository: any MessageRepositoryProtocol
    private let chatRepository: any ChatRepositoryProtocol
    private let delayRange: ClosedRange<Double>
    private let decider: SimulateAgentReplyUseCase
    private var rng = SystemRandomNumberGenerator()

    init(
        messageRepository: any MessageRepositoryProtocol,
        chatRepository: any ChatRepositoryProtocol,
        delayRange: ClosedRange<Double> = 1.0...2.0,
        decider: SimulateAgentReplyUseCase = SimulateAgentReplyUseCase()
    ) {
        self.messageRepository = messageRepository
        self.chatRepository = chatRepository
        self.delayRange = delayRange
        self.decider = decider
    }

    func handleUserMessage(userMessageCount: Int, chat: Chat) async {
        var localRng = rng
        let decision = decider.decide(userMessageCount: userMessageCount, using: &localRng)
        let delay = Double.random(in: delayRange, using: &localRng)
        rng = localRng
        guard decision.shouldReply else { return }
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { return }

        let now = Int64(Date().timeIntervalSince1970 * 1000)

        let agentMessage: Message
        let agentPreview: String

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
            agentPreview = content
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
            agentPreview = "Sent an image"
        }

        try? await messageRepository.insert(agentMessage)

        // Fetch fresh to avoid overwriting title/fields changed since the reply was triggered
        let current = (try? await chatRepository.fetch(id: chat.id)) ?? chat
        let updatedChat = Chat(
            id: current.id,
            title: current.title,
            lastMessage: agentPreview,
            lastMessageTimestamp: now,
            createdAt: current.createdAt,
            updatedAt: now
        )
        try? await chatRepository.update(updatedChat)
    }
}
