protocol MessageRepositoryProtocol: Sendable {
    func fetchMessages(for chatId: String, before: Int64?, limit: Int) async throws -> [Message]
    func newMessageStream(for chatId: String) -> AsyncStream<Message>
    func insert(_ message: Message) async throws
    func deleteAll(for chatId: String) async throws
}
