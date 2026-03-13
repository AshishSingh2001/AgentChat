protocol MessageRepositoryProtocol: Actor {
    func fetchMessages(for chatId: String) async throws -> [Message]
    func insert(_ message: Message) async throws
    func deleteAll(for chatId: String) async throws
}
