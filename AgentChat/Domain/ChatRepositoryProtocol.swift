protocol ChatRepositoryProtocol: Actor {
    func fetchAll() async throws -> [Chat]
    func create(_ chat: Chat) async throws
    func update(_ chat: Chat) async throws
    func delete(id: String) async throws
}
