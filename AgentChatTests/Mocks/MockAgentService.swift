import Foundation
@testable import AgentChat

final class MockAgentService: AgentServiceProtocol, @unchecked Sendable {
    var handleUserMessageCalled = false
    var lastUserMessageCount: Int?
    var lastChat: Chat?
    var shouldReply = false
    var replyMessage: Message?
    var replyDelay: Duration = .milliseconds(50)

    // Optional closure to inject custom reply behaviour per test
    var onHandleUserMessage: ((Int, Chat) async -> Void)?

    func handleUserMessage(userMessageCount: Int, chat: Chat) async {
        handleUserMessageCalled = true
        lastUserMessageCount = userMessageCount
        lastChat = chat
        if let handler = onHandleUserMessage {
            await handler(userMessageCount, chat)
        }
    }
}
