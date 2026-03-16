import Foundation

enum ReplyType {
    case text(String)
    case image(String)  // URL string
}

struct AgentReplyDecision {
    let shouldReply: Bool
    let replyType: ReplyType
}

struct SimulateAgentReplyUseCase: AgentDecider {
    struct Configuration: Sendable {
        /// Reply triggers when userMessageCount % interval == 0
        var replyIntervalRange: ClosedRange<Int>
        /// Probability (0–100) that a reply is an image; remainder is text
        var imageChancePercent: Int

        static nonisolated let `default` = Configuration(
            replyIntervalRange: 4...5,
            imageChancePercent: 30
        )
    }

    let config: Configuration

    nonisolated init(config: Configuration = .default) {
        self.config = config
    }

    nonisolated static let textResponses: [String] = [
        "That's a great point! Let me look into that for you.",
        "I found some useful information that might help.",
        "Interesting! Here's what I can tell you about that.",
        "Sure, I can help with that. Here's what you need to know.",
        "Great question! Let me explain what I found.",
        "I understand what you're looking for. Here's my take.",
        "Thanks for sharing that. Here's what I think.",
        "Let me think about that... I believe the answer is this."
    ]

    nonisolated func decide(userMessagesSinceLastReply userMessageCount: Int, using rng: inout some RandomNumberGenerator) -> AgentReplyDecision {
        guard userMessageCount > 0 else {
            return AgentReplyDecision(shouldReply: false, replyType: .text(""))
        }

        let interval = Int.random(in: config.replyIntervalRange, using: &rng)
        guard userMessageCount % interval == 0 else {
            return AgentReplyDecision(shouldReply: false, replyType: .text(""))
        }

        let roll = Int.random(in: 0..<100, using: &rng)
        if roll < config.imageChancePercent {
            let seed = UUID().uuidString.prefix(8)
            return AgentReplyDecision(shouldReply: true, replyType: .image("https://picsum.photos/seed/\(seed)/400/300"))
        } else {
            let index = Int.random(in: 0..<Self.textResponses.count, using: &rng)
            return AgentReplyDecision(shouldReply: true, replyType: .text(Self.textResponses[index]))
        }
    }
}
