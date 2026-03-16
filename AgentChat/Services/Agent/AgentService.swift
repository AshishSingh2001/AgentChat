import Foundation
import OSLog

actor AgentService: AgentServiceProtocol {
    private nonisolated let log = Logger(subsystem: "com.llance.AgentChat", category: "AgentService")
    private let messageRepository: any MessageRepositoryProtocol
    private let chatRepository: any ChatRepositoryProtocol
    private let delayRange: ClosedRange<Double>
    private let decider: any AgentDecider
    private var rng = SystemRandomNumberGenerator()
    private var pendingTask: Task<Void, Never>?

    init(
        messageRepository: any MessageRepositoryProtocol,
        chatRepository: any ChatRepositoryProtocol,
        delayRange: ClosedRange<Double> = 2.0...3.0,
        decider: any AgentDecider = SimulateAgentReplyUseCase()
    ) {
        self.messageRepository = messageRepository
        self.chatRepository = chatRepository
        self.delayRange = delayRange
        self.decider = decider
    }

    nonisolated func handleUserMessage(chat: Chat) {
        Task { await self.processUserMessage(chat: chat) }
    }

    private func processUserMessage(chat: Chat) async {
        pendingTask?.cancel()
        pendingTask = Task { await self.reply(chat: chat) }
    }

    private func reply(chat: Chat) async {
        let allMessages = (try? await messageRepository.fetchMessages(for: chat.id, before: nil, limit: 100)) ?? []
        var count = 0
        for msg in allMessages.reversed() {
            guard msg.sender == .user else { break }
            count += 1
        }
        log.debug("[\(chat.id)] user messages since last agent reply: \(count)")

        var localRng = rng
        let decision = decider.decide(userMessagesSinceLastReply: count, using: &localRng)
        let delay = Double.random(in: delayRange, using: &localRng)
        rng = localRng

        guard decision.shouldReply else {
            log.debug("[\(chat.id)] skipping reply — gap=\(count)")
            return
        }

        log.debug("[\(chat.id)] will reply in \(String(format: "%.2f", delay))s")
        try? await Task.sleep(for: .seconds(delay))

        guard !Task.isCancelled else {
            log.debug("[\(chat.id)] reply task cancelled (superseded by newer message)")
            return
        }

        let now = Int64(Date().timeIntervalSince1970 * 1000)

        let agentMessage: Message
        let agentPreview: String

        switch decision.replyType {
        case .text(let content):
            log.debug("[\(chat.id)] sending text reply: \"\(content)\"")
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
            log.debug("[\(chat.id)] sending image reply: \(urlString)")
            let thumbnailUrl = urlString.replacingOccurrences(of: "/400/300", with: "/100/100")
            agentMessage = Message(
                id: UUID().uuidString,
                chatId: chat.id,
                text: "",
                type: .file,
                file: FileAttachment(path: urlString, fileSize: 0, thumbnailPath: thumbnailUrl),
                sender: .agent,
                timestamp: now
            )
            agentPreview = "Sent an image"
        }

        do {
            try await messageRepository.insert(agentMessage)
            log.info("[\(chat.id)] agent message inserted successfully")
        } catch {
            log.error("[\(chat.id)] failed to insert agent message: \(error)")
        }

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
        do {
            try await chatRepository.update(updatedChat)
            log.debug("[\(chat.id)] chat lastMessage updated")
        } catch {
            log.error("[\(chat.id)] failed to update chat after agent reply: \(error)")
        }
    }
}
