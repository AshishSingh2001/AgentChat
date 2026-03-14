import Testing
import Foundation
@testable import AgentChat

@MainActor
struct ChatListViewModelTests {

    private func makeVM() -> (ChatListViewModel, MockChatRepository, MockMessageRepository, MockAppRouter) {
        let chatRepo = MockChatRepository()
        let msgRepo = MockMessageRepository()
        let router = MockAppRouter()
        let vm = ChatListViewModel(
            chatRepository: chatRepo,
            messageRepository: msgRepo,
            router: router
        )
        return (vm, chatRepo, msgRepo, router)
    }

    private func drainStream() async {
        for _ in 0..<10 { await Task.yield() }
    }

    @Test func chatsEmptyOnInit() {
        let (vm, _, _, _) = makeVM()
        #expect(vm.chats.isEmpty)
    }

    @Test func isLoadingTrueBeforeStreamStarts() {
        let (vm, _, _, _) = makeVM()
        #expect(vm.isLoading == true)
    }

    @Test func streamPopulatesChats() async throws {
        let (vm, chatRepo, _, _) = makeVM()
        chatRepo.chats = [Chat(id: "1", title: "T", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)]
        vm.startStream()
        await drainStream()
        #expect(vm.chats.count == 1)
        #expect(vm.isLoading == false)
    }

    @Test func createNewChatNavigatesToDetail() async throws {
        let (vm, _, _, router) = makeVM()
        vm.startStream()
        await vm.createNewChat()
        #expect(router.pushedRoutes.count == 1)
        if case .chatDetail(let chatId) = router.pushedRoutes[0] {
            #expect(!chatId.isEmpty)
        } else {
            Issue.record("Expected .chatDetail route")
        }
    }

    @Test func createNewChatAppearsViaStream() async throws {
        let (vm, _, _, _) = makeVM()
        vm.startStream()
        await vm.createNewChat()
        await drainStream()
        #expect(vm.chats.count == 1)
    }

    @Test func deleteChatRemovesViaStream() async throws {
        let (vm, chatRepo, msgRepo, _) = makeVM()
        let chat = Chat(id: "x", title: "T", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        chatRepo.chats = [chat]
        vm.startStream()
        await drainStream()
        #expect(vm.chats.count == 1)
        await vm.deleteChat(chat)
        await drainStream()
        #expect(vm.chats.isEmpty)
        #expect(chatRepo.deletedId == "x")
        #expect(msgRepo.deletedChatIds.contains("x"))
    }

    @Test func chatUpdatesReflectedViaStream() async throws {
        let (vm, chatRepo, _, _) = makeVM()
        let chat = Chat(id: "1", title: "Old", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        chatRepo.chats = [chat]
        vm.startStream()
        await drainStream()
        #expect(vm.chats[0].title == "Old")
        let updated = Chat(id: "1", title: "New", lastMessage: "Hi", lastMessageTimestamp: 1, createdAt: 0, updatedAt: 1)
        try? await chatRepo.update(updated)
        await drainStream()
        #expect(vm.chats[0].title == "New")
        #expect(vm.chats[0].lastMessage == "Hi")
    }
}
