import Foundation

enum ReplyType {
    case text(String)
    case image(String)  // URL string
}

struct AgentReplyDecision {
    let shouldReply: Bool
    let replyType: ReplyType
}

struct SimulateAgentReplyUseCase {
    static let textResponses: [String] = [
        "That's a great point! Let me look into that for you.",
        "I found some useful information that might help.",
        "Interesting! Here's what I can tell you about that.",
        "Sure, I can help with that. Here's what you need to know.",
        "Great question! Let me explain what I found."
    ]

    func decide(userMessageCount: Int, using rng: inout some RandomNumberGenerator) -> AgentReplyDecision {
        guard userMessageCount > 0 else {
            return AgentReplyDecision(shouldReply: false, replyType: .text(""))
        }

        let isImage = Bool.random(using: &rng)
        if isImage {
            return AgentReplyDecision(shouldReply: true, replyType: .image("https://picsum.photos/400/300"))
        } else {
            let index = Int.random(in: 0..<Self.textResponses.count, using: &rng)
            return AgentReplyDecision(shouldReply: true, replyType: .text(Self.textResponses[index]))
        }
    }
}
