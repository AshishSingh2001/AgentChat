import Testing
import Foundation
@testable import AgentChat

@MainActor
struct SimulateAgentReplyUseCaseTests {

    @Test func zeroCountNeverReplies() {
        let useCase = SimulateAgentReplyUseCase()
        var rng = SystemRandomNumberGenerator()
        let decision = useCase.decide(userMessagesSinceLastReply: 0, using: &rng)
        #expect(decision.shouldReply == false)
    }

    // 1, 2, 3, 6, 7, 9 — not divisible by 4 or 5
    @Test func doesNotReplyForNonTriggerCounts() {
        let useCase = SimulateAgentReplyUseCase()
        var rng = SystemRandomNumberGenerator()
        for count in [1, 2, 3, 6, 7, 9] {
            let decision = useCase.decide(userMessagesSinceLastReply: count, using: &rng)
            #expect(decision.shouldReply == false, "Should not reply at count \(count)")
        }
    }

    // 4 is the earliest trigger — fix interval to 4...4 to eliminate randomness
    @Test func repliesAtCount4() {
        let config = SimulateAgentReplyUseCase.Configuration(replyIntervalRange: 4...4, imageChancePercent: 0)
        let useCase = SimulateAgentReplyUseCase(config: config)
        var rng = SystemRandomNumberGenerator()
        let decision = useCase.decide(userMessagesSinceLastReply: 4, using: &rng)
        #expect(decision.shouldReply == true)
    }

    // 5 triggers — fix interval to 5...5 to eliminate randomness
    @Test func repliesAtCount5() {
        let config = SimulateAgentReplyUseCase.Configuration(replyIntervalRange: 5...5, imageChancePercent: 0)
        let useCase = SimulateAgentReplyUseCase(config: config)
        var rng = SystemRandomNumberGenerator()
        let decision = useCase.decide(userMessagesSinceLastReply: 5, using: &rng)
        #expect(decision.shouldReply == true)
    }

    // imageChancePercent=100 → always image; fix interval to eliminate randomness
    @Test func imageChance100AlwaysProducesImage() {
        let config = SimulateAgentReplyUseCase.Configuration(replyIntervalRange: 4...4, imageChancePercent: 100)
        let useCase = SimulateAgentReplyUseCase(config: config)
        var rng = SystemRandomNumberGenerator()
        let decision = useCase.decide(userMessagesSinceLastReply: 4, using: &rng)
        #expect(decision.shouldReply == true)
        guard case .image(let url) = decision.replyType else {
            Issue.record("Expected image reply"); return
        }
        #expect(url.hasPrefix("https://picsum.photos/seed/"))
        #expect(url.hasSuffix("/400/300"))
    }

    // imageChancePercent=0 → always text; fix interval to eliminate randomness
    @Test func imageChance0AlwaysProducesText() {
        let config = SimulateAgentReplyUseCase.Configuration(replyIntervalRange: 4...4, imageChancePercent: 0)
        let useCase = SimulateAgentReplyUseCase(config: config)
        var rng = SystemRandomNumberGenerator()
        let decision = useCase.decide(userMessagesSinceLastReply: 4, using: &rng)
        #expect(decision.shouldReply == true)
        guard case .text(let content) = decision.replyType else {
            Issue.record("Expected text reply"); return
        }
        #expect(!content.isEmpty)
        #expect(SimulateAgentReplyUseCase.textResponses.contains(content))
    }
}
