protocol ChatRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Chat]
    func fetch(id: String) async throws -> Chat?
    func create(_ chat: Chat) async throws
    func update(_ chat: Chat) async throws
    func updateTitle(id: String, title: String) async throws
    func updateDraft(id: String, draftText: String) async throws
    func delete(id: String) async throws
    func chatStream() -> AsyncStream<[Chat]>
}
