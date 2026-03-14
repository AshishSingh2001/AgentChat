import Testing
import Foundation
import UIKit
@testable import AgentChat

@MainActor
struct ChatDetailViewModelTests {

    private func makeVM(
        agentService: MockAgentService? = nil
    ) -> (ChatDetailViewModel, MockChatRepository, MockMessageRepository, MockAgentService) {
        let chatRepo = MockChatRepository()
        let msgRepo = MockMessageRepository()
        let router = MockAppRouter()
        let agent = agentService ?? MockAgentService()
        chatRepo.chats = [Chat(id: "c1", title: "New Chat", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)]
        let vm = ChatDetailViewModel(
            chatId: "c1",
            chatRepository: chatRepo,
            messageRepository: msgRepo,
            router: router,
            fileStorageService: FileStorageService(),
            agentService: agent
        )
        return (vm, chatRepo, msgRepo, agent)
    }

    @Test func messagesEmptyOnInit() {
        let (vm, _, _, _) = makeVM()
        #expect(vm.messages.isEmpty)
    }

    @Test func loadMessagesPopulatesArray() async throws {
        let (vm, _, msgRepo, _) = makeVM()
        msgRepo.messagesByChat["c1"] = [
            Message(id: "m1", chatId: "c1", text: "Hi", type: .text, file: nil, sender: .user, timestamp: 0)
        ]
        await vm.loadMessages()
        try await Task.sleep(for: .milliseconds(50))
        #expect(vm.messages.count == 1)
    }

    @Test func sendEmptyMessageIsNoOp() async throws {
        let (vm, _, _, _) = makeVM()
        await vm.sendMessage(text: "")
        await vm.sendMessage(text: "   ")
        #expect(vm.messages.isEmpty)
    }

    @Test func sendMessageAppendsUserMessage() async throws {
        let (vm, _, _, _) = makeVM()
        await vm.sendMessage(text: "Hello")
        #expect(vm.messages.count == 1)
        #expect(vm.messages[0].text == "Hello")
        #expect(vm.messages[0].sender == .user)
    }

    @Test func sendMessageClearsDraft() async throws {
        let (vm, _, _, _) = makeVM()
        vm.draftText = "work in progress"
        await vm.sendMessage(text: "Hello")
        vm.saveDraftImmediately()
        #expect(vm.draftText == "")
        #expect(UserDefaults.standard.string(forKey: "agentchat.draft.c1") == nil)
    }

    @Test func sendMessageAutoTitlesChat() async throws {
        let (vm, _, _, _) = makeVM()
        await vm.sendMessage(text: "Plan a trip to Paris")
        #expect(vm.chat.title == "Plan a trip to Paris")
    }

    @Test func secondMessageDoesNotOverwriteTitle() async throws {
        let (vm, _, _, _) = makeVM()
        await vm.sendMessage(text: "First message")
        await vm.sendMessage(text: "Second message")
        #expect(vm.chat.title == "First message")
    }

    @Test func agentServiceCalledAfterSend() async throws {
        let (vm, _, _, agent) = makeVM()
        await vm.sendMessage(text: "Hello")
        try await Task.sleep(for: .milliseconds(50))
        #expect(agent.handleUserMessageCalled == true)
        #expect(agent.lastUserMessageCount == 1)
    }

    @Test func agentReplyAppearsViaStream() async throws {
        let (vm, _, msgRepo, agent) = makeVM()
        // Agent inserts a message into the repo, which the stream emits to the VM
        agent.onHandleUserMessage = { _, _ in
            try? await msgRepo.insert(Message(
                id: "agent-1",
                chatId: "c1",
                text: "I can help!",
                type: .text,
                file: nil,
                sender: .agent,
                timestamp: 1
            ))
        }
        await vm.loadMessages()
        await vm.sendMessage(text: "Hello")
        try await Task.sleep(for: .milliseconds(200))
        let agentMessages = vm.messages.filter { $0.sender == .agent }
        #expect(agentMessages.count == 1)
        #expect(agentMessages[0].text == "I can help!")
    }

    @Test func agentDoesNotReplyWhenServiceSkips() async throws {
        let (vm, _, _, _) = makeVM()
        // MockAgentService does nothing by default (no insert)
        await vm.loadMessages()
        await vm.sendMessage(text: "Hello")
        try await Task.sleep(for: .milliseconds(200))
        #expect(vm.messages.filter { $0.sender == .agent }.isEmpty)
    }

    @Test func rapidSendCancelsPreviousAgentTask() async throws {
        let (vm, _, msgRepo, agent) = makeVM()
        var insertCount = 0
        agent.onHandleUserMessage = { _, _ in
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }
            insertCount += 1
            try? await msgRepo.insert(Message(
                id: "agent-\(insertCount)",
                chatId: "c1",
                text: "Reply",
                type: .text,
                file: nil,
                sender: .agent,
                timestamp: Int64(insertCount)
            ))
        }
        await vm.loadMessages()
        await vm.sendMessage(text: "First")
        await vm.sendMessage(text: "Second")  // cancels first agent task
        try await Task.sleep(for: .milliseconds(300))
        let agentMessages = vm.messages.filter { $0.sender == .agent }
        #expect(agentMessages.count == 1)
    }

    @Test func nearBottomTriggersAutoScroll() async throws {
        let (vm, _, _, _) = makeVM()
        vm.isNearBottom = true
        vm.shouldScrollToBottom = false
        await vm.sendMessage(text: "Hello")
        #expect(vm.shouldScrollToBottom == true)
    }

    @Test func farFromBottomShowsToast() async throws {
        let (vm, _, _, _) = makeVM()
        vm.isNearBottom = false
        await vm.sendMessage(text: "Hello")
        #expect(vm.showNewMessageToast == true)
    }

    @Test func dismissToastClearsState() {
        let (vm, _, _, _) = makeVM()
        vm.showNewMessageToast = true
        vm.dismissToast()
        #expect(vm.showNewMessageToast == false)
    }

    @Test func startTitleEditSetsFlag() {
        let (vm, _, _, _) = makeVM()
        vm.startTitleEdit()
        #expect(vm.isTitleEditing == true)
    }

    @Test func commitTitleEditUpdatesTitle() async throws {
        let (vm, chatRepo, _, _) = makeVM()
        vm.startTitleEdit()
        await vm.commitTitleEdit(newTitle: "My Custom Title")
        #expect(vm.chat.title == "My Custom Title")
        #expect(vm.isTitleEditing == false)
        #expect(chatRepo.updatedChat?.title == "My Custom Title")
    }

    @Test func draftRestoredFromUserDefaults() {
        UserDefaults.standard.set("saved draft", forKey: "agentchat.draft.c1")
        defer { UserDefaults.standard.removeObject(forKey: "agentchat.draft.c1") }
        let (vm, _, _, _) = makeVM()
        #expect(vm.draftText == "saved draft")
    }

    @Test func updateScrollOffsetSetsIsNearBottom() {
        let (vm, _, _, _) = makeVM()
        vm.updateScrollOffset(100)
        #expect(vm.isNearBottom == true)
        vm.updateScrollOffset(200)
        #expect(vm.isNearBottom == false)
    }

    @Test func saveDraftImmediatelyWritesToUserDefaults() {
        let (vm, _, _, _) = makeVM()
        vm.draftText = "immediate save"
        vm.saveDraftImmediately()
        #expect(UserDefaults.standard.string(forKey: "agentchat.draft.c1") == "immediate save")
        UserDefaults.standard.removeObject(forKey: "agentchat.draft.c1")
    }

    @Test func draftDebounceEventuallySavesToUserDefaults() async throws {
        let chatRepo = MockChatRepository()
        let msgRepo = MockMessageRepository()
        let router = MockAppRouter()
        let uniqueId = "debounce-test-\(UUID().uuidString)"
        chatRepo.chats = [Chat(id: uniqueId, title: "New Chat", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)]
        let vm = ChatDetailViewModel(
            chatId: uniqueId,
            chatRepository: chatRepo,
            messageRepository: msgRepo,
            router: router,
            fileStorageService: FileStorageService(),
            agentService: MockAgentService()
        )
        let key = "agentchat.draft.\(uniqueId)"
        UserDefaults.standard.removeObject(forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }
        vm.draftText = "debounced"
        try await Task.sleep(for: .milliseconds(500))
        #expect(UserDefaults.standard.string(forKey: key) == "debounced")
    }

    @Test func sendWithAttachmentAppendsFileMessage() async throws {
        let (vm, _, _, _) = makeVM()
        let imageData = UIImage(systemName: "photo")!.jpegData(compressionQuality: 0.8) ?? Data()
        let image = UIImage(systemName: "photo")!
        vm.setPendingAttachment(PendingAttachment(data: imageData, previewImage: image))
        await vm.sendWithAttachment()
        #expect(vm.messages.count == 1)
        #expect(vm.messages[0].type == .file)
        #expect(vm.messages[0].sender == .user)
        #expect(vm.pendingAttachment == nil)
    }
}
