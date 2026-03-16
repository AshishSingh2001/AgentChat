import Foundation

protocol AgentServiceProtocol: Sendable {
    func handleUserMessage(chat: Chat)
}

protocol AgentDecider: Sendable {
    nonisolated func decide(userMessagesSinceLastReply: Int, using rng: inout some RandomNumberGenerator) -> AgentReplyDecision
}
