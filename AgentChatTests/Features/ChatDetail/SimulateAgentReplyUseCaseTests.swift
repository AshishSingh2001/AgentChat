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

    // count=4, divisor=4 (0 → lower bound → 4): 4 % 4 == 0 → shouldReply
    @Test func count4Divisor4Replies() {
        var rng = FixedRNG(0)
        let decision = useCase.decide(userMessageCount: 4, using: &rng)
        #expect(decision.shouldReply == true)
    }

    // count=4, divisor=5 (UInt64.max → upper bound → 5): 4 % 5 != 0 → no reply
    @Test func count4Divisor5NoReply() {
        var rng = FixedRNG(UInt64.max)
        let decision = useCase.decide(userMessageCount: 4, using: &rng)
        #expect(decision.shouldReply == false)
    }

    // count=5, divisor=5: 5 % 5 == 0 → shouldReply
    @Test func count5Divisor5Replies() {
        var rng = FixedRNG(UInt64.max)
        let decision = useCase.decide(userMessageCount: 5, using: &rng)
        #expect(decision.shouldReply == true)
    }

    // count=6, divisor=5: 6 % 5 != 0 → no reply
    @Test func count6Divisor5NoReply() {
        var rng = FixedRNG(UInt64.max)
        let decision = useCase.decide(userMessageCount: 6, using: &rng)
        #expect(decision.shouldReply == false)
    }

    // shouldReply + text: 0→divisor=4 (4%4=0), UInt64.max→Bool.random=false (text), 0→index=0
    // Note: Bool.random(using:) with next()=0 → true, next()=UInt64.max → false
    @Test func repliesWithTextWhenRNGFavorsText() {
        var rng = FixedRNG(0, UInt64.max, 0)
        let decision = useCase.decide(userMessageCount: 4, using: &rng)
        #expect(decision.shouldReply == true)
        if case .text(let content) = decision.replyType {
            #expect(!content.isEmpty)
            #expect(SimulateAgentReplyUseCase.textResponses.contains(content))
        } else {
            Issue.record("Expected text reply")
        }
    }

    // shouldReply + image: 0→divisor=4 (4%4=0), 0→Bool.random=true (image)
    @Test func repliesWithImageWhenRNGFavorsImage() {
        var rng = FixedRNG(0, 0)
        let decision = useCase.decide(userMessageCount: 4, using: &rng)
        #expect(decision.shouldReply == true)
        if case .image(let url) = decision.replyType {
            #expect(url == "https://picsum.photos/400/300")
        } else {
            Issue.record("Expected image reply")
        }
    }

    @Test func zeroCountDoesNotReply() {
        var rng = FixedRNG(0)
        let decision = useCase.decide(userMessageCount: 0, using: &rng)
        #expect(decision.shouldReply == false)
    }
}
