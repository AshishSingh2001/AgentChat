import Foundation

protocol AgentServiceProtocol: Sendable {
    func handleUserMessage(userMessageCount: Int, chat: Chat) async
}
