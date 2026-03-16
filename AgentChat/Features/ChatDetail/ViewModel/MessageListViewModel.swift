import Foundation
import OSLog

@Observable
@MainActor
final class MessageListViewModel {
    private(set) var messages: [Message] = []
    private(set) var isLoadingOlder = false
    private(set) var hasMoreMessages = true
    
    private nonisolated let log = Logger(subsystem: "com.llance.AgentChat", category: "MessageListViewModel")

    var onNewMessage: ((Message) -> Void)?

    private let pageSize = 15
    private var streamTask: Task<Void, Never>?
    private var oldestTimestamp: Int64? { messages.first?.timestamp }

    func load(chatId: String, repository: any MessageRepositoryProtocol) async {
        let page = (try? await repository.fetchMessages(for: chatId, before: nil, limit: pageSize)) ?? []
        messages = page
        hasMoreMessages = page.count == pageSize

        streamTask?.cancel()
        streamTask = Task {
            for await newMessage in repository.newMessageStream(for: chatId) {
                guard !Task.isCancelled else { break }
                guard !messages.contains(where: { $0.id == newMessage.id }) else { continue }
                messages.append(newMessage)
                onNewMessage?(newMessage)
            }
        }
    }

    func loadOlderMessages(chatId: String, repository: any MessageRepositoryProtocol) async {
        guard hasMoreMessages, !isLoadingOlder, let cursor = oldestTimestamp else {
            print("[MessageList] loadOlderMessages skipped — hasMore=\(hasMoreMessages) isLoading=\(isLoadingOlder) cursor=\(String(describing: oldestTimestamp))")
            return
        }
        print("[MessageList] loading older — cursor=\(cursor) currentFirst=\(messages.first?.id ?? "nil")")
        isLoadingOlder = true
        defer { isLoadingOlder = false }

        let page = (try? await repository.fetchMessages(for: chatId, before: cursor, limit: pageSize)) ?? []
        print("[MessageList] loaded \(page.count) older messages — firstInPage=\(page.first?.id ?? "nil")")
        hasMoreMessages = page.count == pageSize
        messages = page + messages
        print("[MessageList] messages array updated — total=\(messages.count) firstId=\(messages.first?.id ?? "nil")")
    }

    func appendIfAbsent(_ message: Message) {
        guard !messages.contains(where: { $0.id == message.id }) else { return }
        messages.append(message)
        onNewMessage?(message)
    }

    func cancelStream() {
        streamTask?.cancel()
        streamTask = nil
    }
}
