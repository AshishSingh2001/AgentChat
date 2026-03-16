import Foundation
@testable import AgentChat

final class MockAgentService: AgentServiceProtocol, @unchecked Sendable {
    var handleUserMessageCalled = false
    var lastChat: Chat?
    var shouldReply = false
    var replyMessage: Message?
    var replyDelay: Duration = .milliseconds(50)

    // Optional closure to inject custom reply behaviour per test
    var onHandleUserMessage: ((Chat) -> Void)?

    func handleUserMessage(chat: Chat) {
        handleUserMessageCalled = true
        lastChat = chat
        onHandleUserMessage?(chat)
    }
}
