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

    @Test func chatsEmptyOnInit() {
        let (vm, _, _, _) = makeVM()
        #expect(vm.chats.isEmpty)
    }

    @Test func loadChatsPopulatesArray() async throws {
        let (vm, chatRepo, _, _) = makeVM()
        chatRepo.chats = [Chat(id: "1", title: "T", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)]
        await vm.loadChats()
        #expect(vm.chats.count == 1)
    }

    @Test func createNewChatNavigatesToDetail() async throws {
        let (vm, _, _, router) = makeVM()
        await vm.createNewChat()
        #expect(router.pushedRoutes.count == 1)
        if case .chatDetail(let chatId) = router.pushedRoutes[0] {
            #expect(!chatId.isEmpty)
        } else {
            Issue.record("Expected .chatDetail route")
        }
    }

    @Test func createNewChatAppendsToList() async throws {
        let (vm, _, _, _) = makeVM()
        await vm.createNewChat()
        #expect(vm.chats.count == 1)
    }

    @Test func deleteChatRemovesFromListAndRepo() async throws {
        let (vm, chatRepo, msgRepo, _) = makeVM()
        let chat = Chat(id: "x", title: "T", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)
        chatRepo.chats = [chat]
        await vm.loadChats()
        await vm.deleteChat(chat)
        #expect(vm.chats.isEmpty)
        #expect(chatRepo.deletedId == "x")
        #expect(msgRepo.deletedChatIds.contains("x"))
    }

    @Test func reloadAfterNavPopReflectsLatestData() async throws {
        let (vm, chatRepo, _, _) = makeVM()
        await vm.loadChats()
        #expect(vm.chats.isEmpty)
        chatRepo.chats = [Chat(id: "1", title: "T", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)]
        await vm.loadChats()
        #expect(vm.chats.count == 1)
    }
}
