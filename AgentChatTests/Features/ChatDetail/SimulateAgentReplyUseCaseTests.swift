import Testing
import Foundation
@testable import AgentChat

// Deterministic RNG: 0 maps to lower bound of any Int range, UInt64.max maps to upper bound.
private struct FixedRNG: RandomNumberGenerator {
    var values: [UInt64]
    var index = 0

    init(_ values: UInt64...) { self.values = values }

    mutating func next() -> UInt64 {
        defer { index = (index + 1) % values.count }
        return values[index]
    }
}

@MainActor
struct SimulateAgentReplyUseCaseTests {
    let useCase = SimulateAgentReplyUseCase()

    // Any positive count always triggers a reply
    @Test func positiveCountAlwaysReplies() {
        var rng = FixedRNG(0)
        let decision = useCase.decide(userMessageCount: 1, using: &rng)
        #expect(decision.shouldReply == true)
    }

    @Test func zeroCountDoesNotReply() {
        var rng = FixedRNG(0)
        let decision = useCase.decide(userMessageCount: 0, using: &rng)
        #expect(decision.shouldReply == false)
    }

    // Bool.random(using:) with next()=UInt64.max → false (text), next()=0 → index=0
    @Test func repliesWithTextWhenRNGFavorsText() {
        var rng = FixedRNG(UInt64.max, 0)
        let decision = useCase.decide(userMessageCount: 1, using: &rng)
        #expect(decision.shouldReply == true)
        if case .text(let content) = decision.replyType {
            #expect(!content.isEmpty)
            #expect(SimulateAgentReplyUseCase.textResponses.contains(content))
        } else {
            Issue.record("Expected text reply")
        }
    }

    // Bool.random(using:) with next()=0 → true (image)
    @Test func repliesWithImageWhenRNGFavorsImage() {
        var rng = FixedRNG(0)
        let decision = useCase.decide(userMessageCount: 1, using: &rng)
        #expect(decision.shouldReply == true)
        if case .image(let url) = decision.replyType {
            #expect(url == "https://picsum.photos/400/300")
        } else {
            Issue.record("Expected image reply")
        }
    }
}
