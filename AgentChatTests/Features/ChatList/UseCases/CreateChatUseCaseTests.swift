import Testing
import Foundation
@testable import AgentChat

@MainActor
struct CreateChatUseCaseTests {

    @Test func createsUniqueUUIDs() async throws {
        let repo = MockChatRepository()
        let useCase = CreateChatUseCase(chatRepository: repo)
        let chat1 = try await useCase.execute()
        let chat2 = try await useCase.execute()
        #expect(!chat1.id.isEmpty)
        #expect(!chat2.id.isEmpty)
        #expect(chat1.id != chat2.id)
    }

    @Test func setsDefaultTitle() async throws {
        let repo = MockChatRepository()
        let useCase = CreateChatUseCase(chatRepository: repo)
        let chat = try await useCase.execute()
        #expect(chat.title == "New Chat")
    }

    @Test func setsTimestampsToCurrentTime() async throws {
        let repo = MockChatRepository()
        let useCase = CreateChatUseCase(chatRepository: repo)
        let before = Int64(Date().timeIntervalSince1970 * 1000)
        let chat = try await useCase.execute()
        let after = Int64(Date().timeIntervalSince1970 * 1000)
        #expect(chat.createdAt >= before)
        #expect(chat.createdAt <= after)
        #expect(chat.updatedAt == chat.createdAt)
    }

    @Test func persistsChatInRepository() async throws {
        let repo = MockChatRepository()
        let useCase = CreateChatUseCase(chatRepository: repo)
        let chat = try await useCase.execute()
        let fetched = try await repo.fetchAll()
        #expect(fetched.count == 1)
        #expect(fetched[0].id == chat.id)
    }
}
