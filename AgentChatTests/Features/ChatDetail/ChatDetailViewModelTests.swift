import Testing
import Foundation
import UIKit
@testable import AgentChat

@MainActor
struct ChatDetailViewModelTests {

    private func makeVM(
        agentReplyDecider: ((Int) -> AgentReplyDecision)? = nil
    ) -> (ChatDetailViewModel, MockChatRepository, MockMessageRepository) {
        let chatRepo = MockChatRepository()
        let msgRepo = MockMessageRepository()
        let router = MockAppRouter()
        chatRepo.chats = [Chat(id: "c1", title: "New Chat", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)]
        let vm = ChatDetailViewModel(
            chatId: "c1",
            chatRepository: chatRepo,
            messageRepository: msgRepo,
            router: router,
            fileStorageService: FileStorageService(),
            agentReplyDelayRange: 0.05...0.05,
            agentReplyDecider: agentReplyDecider
        )
        return (vm, chatRepo, msgRepo)
    }

    @Test func messagesEmptyOnInit() {
        let (vm, _, _) = makeVM()
        #expect(vm.messages.isEmpty)
    }

    @Test func loadMessagesPopulatesArray() async throws {
        let (vm, _, msgRepo) = makeVM()
        msgRepo.messagesByChat["c1"] = [
            Message(id: "m1", chatId: "c1", text: "Hi", type: .text, file: nil, sender: .user, timestamp: 0)
        ]
        await vm.loadMessages()
        #expect(vm.messages.count == 1)
    }

    @Test func sendEmptyMessageIsNoOp() async throws {
        let (vm, _, _) = makeVM()
        await vm.sendMessage(text: "")
        await vm.sendMessage(text: "   ")
        #expect(vm.messages.isEmpty)
    }

    @Test func sendMessageAppendsUserMessage() async throws {
        let (vm, _, _) = makeVM()
        await vm.sendMessage(text: "Hello")
        #expect(vm.messages.count == 1)
        #expect(vm.messages[0].text == "Hello")
        #expect(vm.messages[0].sender == .user)
    }

    @Test func sendMessageClearsDraft() async throws {
        let (vm, _, _) = makeVM()
        vm.draftText = "work in progress"
        await vm.sendMessage(text: "Hello")
        vm.saveDraftImmediately()
        #expect(vm.draftText == "")
        #expect(UserDefaults.standard.string(forKey: "agentchat.draft.c1") == nil)
    }

    @Test func sendMessageAutoTitlesChat() async throws {
        let (vm, _, _) = makeVM()
        await vm.sendMessage(text: "Plan a trip to Paris")
        #expect(vm.chat.title == "Plan a trip to Paris")
    }

    @Test func secondMessageDoesNotOverwriteTitle() async throws {
        let (vm, _, _) = makeVM()
        await vm.sendMessage(text: "First message")
        await vm.sendMessage(text: "Second message")
        #expect(vm.chat.title == "First message")
    }

    @Test func agentRepliesWhenDeciderSaysReply() async throws {
        let alwaysReply: (Int) -> AgentReplyDecision = { _ in
            AgentReplyDecision(shouldReply: true, replyType: .text("I can help!"))
        }
        let (vm, _, _) = makeVM(agentReplyDecider: alwaysReply)
        await vm.sendMessage(text: "Hello")
        try await Task.sleep(for: .milliseconds(300))
        #expect(vm.messages.count == 2)
        #expect(vm.messages[1].sender == .agent)
        #expect(vm.messages[1].text == "I can help!")
    }

    @Test func agentDoesNotReplyWhenDeciderSaysNo() async throws {
        let neverReply: (Int) -> AgentReplyDecision = { _ in
            AgentReplyDecision(shouldReply: false, replyType: .text(""))
        }
        let (vm, _, _) = makeVM(agentReplyDecider: neverReply)
        await vm.sendMessage(text: "Hello")
        try await Task.sleep(for: .milliseconds(300))
        #expect(vm.messages.count == 1)
    }

    @Test func rapidSendCancelsPreviousReply() async throws {
        let alwaysReply: (Int) -> AgentReplyDecision = { _ in
            AgentReplyDecision(shouldReply: true, replyType: .text("Reply"))
        }
        let (vm, _, _) = makeVM(agentReplyDecider: alwaysReply)
        await vm.sendMessage(text: "First")
        await vm.sendMessage(text: "Second")
        try await Task.sleep(for: .milliseconds(300))
        let agentMessages = vm.messages.filter { $0.sender == .agent }
        #expect(agentMessages.count == 1)
    }

    @Test func nearBottomTriggersAutoScroll() async throws {
        let (vm, _, _) = makeVM()
        vm.isNearBottom = true
        vm.shouldScrollToBottom = false
        await vm.sendMessage(text: "Hello")
        #expect(vm.shouldScrollToBottom == true)
    }

    @Test func farFromBottomShowsToast() async throws {
        let neverReply: (Int) -> AgentReplyDecision = { _ in
            AgentReplyDecision(shouldReply: false, replyType: .text(""))
        }
        let (vm, _, _) = makeVM(agentReplyDecider: neverReply)
        vm.isNearBottom = false
        await vm.sendMessage(text: "Hello")
        #expect(vm.showNewMessageToast == true)
    }

    @Test func dismissToastClearsState() {
        let (vm, _, _) = makeVM()
        vm.showNewMessageToast = true
        vm.dismissToast()
        #expect(vm.showNewMessageToast == false)
    }

    @Test func startTitleEditSetsFlag() {
        let (vm, _, _) = makeVM()
        vm.startTitleEdit()
        #expect(vm.isTitleEditing == true)
    }

    @Test func commitTitleEditUpdatesTitle() async throws {
        let (vm, chatRepo, _) = makeVM()
        vm.startTitleEdit()
        await vm.commitTitleEdit(newTitle: "My Custom Title")
        #expect(vm.chat.title == "My Custom Title")
        #expect(vm.isTitleEditing == false)
        #expect(chatRepo.updatedChat?.title == "My Custom Title")
    }

    @Test func draftRestoredFromUserDefaults() {
        UserDefaults.standard.set("saved draft", forKey: "agentchat.draft.c1")
        defer { UserDefaults.standard.removeObject(forKey: "agentchat.draft.c1") }
        let (vm, _, _) = makeVM()
        #expect(vm.draftText == "saved draft")
    }

    @Test func updateScrollOffsetSetsIsNearBottom() {
        let (vm, _, _) = makeVM()
        vm.updateScrollOffset(100)
        #expect(vm.isNearBottom == true)
        vm.updateScrollOffset(200)
        #expect(vm.isNearBottom == false)
    }

    @Test func saveDraftImmediatelyWritesToUserDefaults() {
        let (vm, _, _) = makeVM()
        vm.draftText = "immediate save"
        // Debounce would delay the save — saveDraftImmediately flushes it now
        vm.saveDraftImmediately()
        #expect(UserDefaults.standard.string(forKey: "agentchat.draft.c1") == "immediate save")
        UserDefaults.standard.removeObject(forKey: "agentchat.draft.c1")
    }

    @Test func draftDebounceEventuallySavesToUserDefaults() async throws {
        // Use a unique chatId to avoid cross-test UserDefaults pollution
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
            agentReplyDelayRange: 0.05...0.05
        )
        let key = "agentchat.draft.\(uniqueId)"
        UserDefaults.standard.removeObject(forKey: key)
        defer { UserDefaults.standard.removeObject(forKey: key) }

        vm.draftText = "debounced"
        // After 500ms, debounce (300ms) has fired
        try await Task.sleep(for: .milliseconds(500))
        #expect(UserDefaults.standard.string(forKey: key) == "debounced")
    }

    @Test func sendWithAttachmentAppendsFileMessage() async throws {
        let neverReply: (Int) -> AgentReplyDecision = { _ in
            AgentReplyDecision(shouldReply: false, replyType: .text(""))
        }
        let (vm, _, _) = makeVM(agentReplyDecider: neverReply)
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
