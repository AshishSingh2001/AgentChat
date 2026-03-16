import Testing
import Foundation
import UIKit
@testable import AgentChat

@MainActor
struct ChatDetailViewModelTests {

    private static let defaultChat = Chat(id: "c1", title: "New Chat", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0)

    private func makeVM(
        chat: Chat? = nil,
        agentService: MockAgentService? = nil
    ) -> (ChatDetailViewModel, MockChatRepository, MockMessageRepository, MockAgentService) {
        let chat = chat ?? Self.defaultChat
        let chatRepo = MockChatRepository()
        let msgRepo = MockMessageRepository()
        let agent = agentService ?? MockAgentService()
        let router = MockAppRouter()
        chatRepo.chats = [chat]
        let vm = ChatDetailViewModel(
            chat: chat,
            chatRepository: chatRepo,
            messageRepository: msgRepo,
            router: router,
            agentService: agent
        )
        return (vm, chatRepo, msgRepo, agent)
    }

    // Yield the main actor enough times for the stream Task to process one emission.
    private func drainStream() async {
        for _ in 0..<10 { await Task.yield() }
    }

    @Test func messagesEmptyOnInit() {
        let (vm, _, _, _) = makeVM()
        #expect(vm.messages.messages.isEmpty)
    }

    @Test func loadMessagesPopulatesArray() async throws {
        let (vm, _, msgRepo, _) = makeVM()
        msgRepo.messagesByChat["c1"] = [
            Message(id: "m1", chatId: "c1", text: "Hi", type: .text, file: nil, sender: .user, timestamp: 0)
        ]
        await vm.loadMessages()
        #expect(vm.messages.messages.count == 1)
    }

    @Test func sendEmptyMessageIsNoOp() async throws {
        let (vm, _, _, _) = makeVM()
        await vm.loadMessages()
        await vm.sendMessage(text: "")
        await vm.sendMessage(text: "   ")
        await drainStream()
        #expect(vm.messages.messages.isEmpty)
    }

    // Fully reactive: message appears via stream after DB insert
    @Test func sendMessageAppearsViaStream() async throws {
        let (vm, _, _, _) = makeVM()
        await vm.loadMessages()
        await vm.sendMessage(text: "Hello")
        await drainStream()
        try #require(vm.messages.messages.count == 1)
        #expect(vm.messages.messages[0].text == "Hello")
        #expect(vm.messages.messages[0].sender == .user)
    }

    @Test func sendMessageClearsDraft() async throws {
        let (vm, chatRepo, _, _) = makeVM()
        await vm.loadMessages()
        vm.draft.text = "work in progress"
        await vm.sendMessage(text: "Hello")
        #expect(vm.draft.text == "")
        #expect(chatRepo.updatedChat?.draftText == "")
    }

    @Test func sendMessageAutoTitlesChat() async throws {
        let (vm, _, _, _) = makeVM()
        await vm.loadMessages()
        await vm.sendMessage(text: "Plan a trip to Paris")
        #expect(vm.title.chat.title == "Plan a trip to Paris")
    }

    @Test func secondMessageDoesNotOverwriteTitle() async throws {
        let (vm, _, _, _) = makeVM()
        await vm.loadMessages()
        await vm.sendMessage(text: "First message")
        await drainStream()
        await vm.sendMessage(text: "Second message")
        #expect(vm.title.chat.title == "First message")
    }

    @Test func agentServiceCalledAfterSend() async throws {
        let (vm, _, _, agent) = makeVM()
        await vm.loadMessages()
        await vm.sendMessage(text: "Hello")
        await drainStream()
        #expect(agent.handleUserMessageCalled == true)
    }

    @Test func agentReplyAppearsViaStream() async throws {
        let (vm, _, msgRepo, agent) = makeVM()
        agent.onHandleUserMessage = { _ in
            Task {
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
        }
        await vm.loadMessages()
        await vm.sendMessage(text: "Hello")
        try await Task.sleep(for: .milliseconds(200))
        let agentMessages = vm.messages.messages.filter { $0.sender == .agent }
        try #require(agentMessages.count == 1)
        #expect(agentMessages[0].text == "I can help!")
    }

    @Test func agentDoesNotReplyWhenServiceSkips() async throws {
        let (vm, _, _, _) = makeVM()
        await vm.loadMessages()
        await vm.sendMessage(text: "Hello")
        try await Task.sleep(for: .milliseconds(200))
        #expect(vm.messages.messages.filter { $0.sender == .agent }.isEmpty)
    }

    @Test func rapidSendCallsAgentServiceForEachMessage() async throws {
        let (vm, _, _, agent) = makeVM()
        var callCount = 0
        agent.onHandleUserMessage = { _ in callCount += 1 }
        await vm.loadMessages()
        await vm.sendMessage(text: "First")
        await vm.sendMessage(text: "Second")
        #expect(callCount == 2)
    }

    // User message near bottom → auto-scroll
    @Test func userMessageNearBottomTriggersAutoScroll() async throws {
        let (vm, _, msgRepo, _) = makeVM()
        await vm.loadMessages()
        vm.scroll.isNearBottom = true
        vm.scroll.shouldScrollToBottom = false
        msgRepo.simulateIncomingMessage(Message(id: "m1", chatId: "c1", text: "Hi", type: .text, file: nil, sender: .user, timestamp: 0))
        await drainStream()
        #expect(vm.scroll.shouldScrollToBottom == true)
        #expect(vm.scroll.showNewMessageToast == false)
    }

    // User message always auto-scrolls regardless of scroll position
    @Test func userMessageFarFromBottomStillAutoScrolls() async throws {
        let (vm, _, msgRepo, _) = makeVM()
        await vm.loadMessages()
        vm.scroll.isNearBottom = false
        vm.scroll.shouldScrollToBottom = false
        msgRepo.simulateIncomingMessage(Message(id: "m1", chatId: "c1", text: "Hi", type: .text, file: nil, sender: .user, timestamp: 0))
        await drainStream()
        #expect(vm.scroll.shouldScrollToBottom == true)
        #expect(vm.scroll.showNewMessageToast == false)
    }

    // Agent message when scrolled away → shows toast (does not force-scroll)
    @Test func agentMessageFarFromBottomShowsToast() async throws {
        let (vm, _, msgRepo, _) = makeVM()
        await vm.loadMessages()
        vm.scroll.isNearBottom = false
        vm.scroll.shouldScrollToBottom = false
        msgRepo.simulateIncomingMessage(Message(id: "m1", chatId: "c1", text: "Reply", type: .text, file: nil, sender: .agent, timestamp: 0))
        await drainStream()
        #expect(vm.scroll.showNewMessageToast == true)
        #expect(vm.scroll.shouldScrollToBottom == false)
    }

    // Agent message when near bottom → auto-scrolls
    @Test func agentMessageNearBottomAutoScrolls() async throws {
        let (vm, _, msgRepo, _) = makeVM()
        await vm.loadMessages()
        vm.scroll.isNearBottom = true
        vm.scroll.shouldScrollToBottom = false
        msgRepo.simulateIncomingMessage(Message(id: "m1", chatId: "c1", text: "Reply", type: .text, file: nil, sender: .agent, timestamp: 0))
        await drainStream()
        #expect(vm.scroll.shouldScrollToBottom == true)
        #expect(vm.scroll.showNewMessageToast == false)
    }

    @Test func dismissToastClearsState() {
        let (vm, _, _, _) = makeVM()
        vm.scroll.showNewMessageToast = true
        vm.scroll.dismissToast()
        #expect(vm.scroll.showNewMessageToast == false)
    }

    @Test func startTitleEditSetsFlag() {
        let (vm, _, _, _) = makeVM()
        vm.title.startEdit()
        #expect(vm.title.isTitleEditing == true)
    }

    @Test func commitTitleEditUpdatesTitle() async throws {
        let (vm, chatRepo, _, _) = makeVM()
        vm.title.startEdit()
        await vm.commitTitleEdit(newTitle: "My Custom Title")
        #expect(vm.title.chat.title == "My Custom Title")
        #expect(vm.title.isTitleEditing == false)
        #expect(chatRepo.updatedChat?.title == "My Custom Title")
    }

    @Test func commitTitleEditIgnoresEmptyString() async throws {
        let (vm, chatRepo, _, _) = makeVM()
        await vm.loadMessages()
        vm.title.startEdit()
        await vm.commitTitleEdit(newTitle: "   ")
        #expect(chatRepo.updatedChat == nil)
        #expect(vm.title.isTitleEditing == false)
    }

    @Test func draftRestoredFromChat() {
        let chatWithDraft = Chat(id: "c1", title: "New Chat", lastMessage: "", lastMessageTimestamp: 0, createdAt: 0, updatedAt: 0, draftText: "saved draft")
        let (vm, _, _, _) = makeVM(chat: chatWithDraft)
        #expect(vm.draft.text == "saved draft")
    }

    @Test func updateScrollOffsetSetsIsNearBottom() {
        let (vm, _, _, _) = makeVM()
        vm.scroll.updateScrollOffset(100)
        #expect(vm.scroll.isNearBottom == true)
        vm.scroll.updateScrollOffset(200)
        #expect(vm.scroll.isNearBottom == false)
    }

    // Threshold is < 150: 149 → near, 150 → NOT near, 151 → NOT near
    @Test func scrollOffsetThresholdBoundary() {
        let (vm, _, _, _) = makeVM()
        vm.scroll.updateScrollOffset(149)
        #expect(vm.scroll.isNearBottom == true)
        vm.scroll.updateScrollOffset(150)
        #expect(vm.scroll.isNearBottom == false)
        vm.scroll.updateScrollOffset(151)
        #expect(vm.scroll.isNearBottom == false)
    }

    @Test func shouldScrollToBottomCanBeResetByConsumer() async throws {
        let (vm, _, msgRepo, _) = makeVM()
        await vm.loadMessages()
        vm.scroll.isNearBottom = true
        msgRepo.simulateIncomingMessage(Message(id: "m1", chatId: "c1", text: "Hi", type: .text, file: nil, sender: .user, timestamp: 0))
        await drainStream()
        #expect(vm.scroll.shouldScrollToBottom == true)
        vm.scroll.shouldScrollToBottom = false
        #expect(vm.scroll.shouldScrollToBottom == false)
    }

    @Test func openImageViewerSetsSelectedURLForRemoteURL() {
        let (vm, _, _, _) = makeVM()
        let url = URL(string: "https://picsum.photos/400/300")!
        vm.imageViewer.open(url: url)
        #expect(vm.imageViewer.selectedImageURL == url)
    }

    @Test func openImageViewerSetsSelectedURLForLocalURL() {
        let (vm, _, _, _) = makeVM()
        let url = URL(fileURLWithPath: "/tmp/some-image.jpg")
        vm.imageViewer.open(url: url)
        #expect(vm.imageViewer.selectedImageURL == url)
    }

    // isTitleEditing resets to false even when the repository update throws
    @Test func commitTitleEditResetsFlagEvenOnError() async throws {
        let (vm, chatRepo, _, _) = makeVM()
        chatRepo.shouldThrowError = ChatError.updateFailed(underlying: nil)
        chatRepo.errorOnMethod = .update
        vm.title.startEdit()
        #expect(vm.title.isTitleEditing == true)
        await vm.commitTitleEdit(newTitle: "Whatever")
        #expect(vm.title.isTitleEditing == false)
        #expect(vm.errorMessage != nil)
    }

    @Test func saveDraftImmediatelyPersistsToRepository() async throws {
        let (vm, chatRepo, _, _) = makeVM()
        await vm.loadMessages()
        vm.draft.text = "immediate save"
        vm.saveDraftImmediately()
        await drainStream()
        #expect(chatRepo.updatedChat?.draftText == "immediate save")
    }

    @Test func draftDebounceEventuallyPersistsToRepository() async throws {
        let (vm, chatRepo, _, _) = makeVM()
        vm.draft.text = "debounced"
        try await Task.sleep(for: .milliseconds(500))
        #expect(chatRepo.updatedChat?.draftText == "debounced")
    }

    // MARK: - cleanUpIfEmpty

    @Test func cleanUpIfEmptyDeletesChatWhenNoMessagesAndNoDraft() async throws {
        let (vm, chatRepo, _, _) = makeVM()
        await vm.loadMessages()
        vm.cleanUpIfEmpty()
        await drainStream()
        #expect(chatRepo.deletedId == "c1")
    }

    @Test func cleanUpIfEmptyDoesNotDeleteWhenMessagesExist() async throws {
        let (vm, chatRepo, msgRepo, _) = makeVM()
        msgRepo.messagesByChat["c1"] = [
            Message(id: "m1", chatId: "c1", text: "Hi", type: .text, file: nil, sender: .user, timestamp: 0)
        ]
        await vm.loadMessages()
        vm.cleanUpIfEmpty()
        await drainStream()
        #expect(chatRepo.deletedId == nil)
    }

    @Test func cleanUpIfEmptyDoesNotDeleteWhenDraftExists() async throws {
        let (vm, chatRepo, _, _) = makeVM()
        await vm.loadMessages()
        vm.draft.text = "unfinished thought"
        vm.cleanUpIfEmpty()
        await drainStream()
        #expect(chatRepo.deletedId == nil)
    }

    @Test func cleanUpIfEmptyDeletesWhenDraftIsWhitespaceOnly() async throws {
        let (vm, chatRepo, _, _) = makeVM()
        await vm.loadMessages()
        vm.draft.text = "   "
        vm.cleanUpIfEmpty()
        await drainStream()
        #expect(chatRepo.deletedId == "c1")
    }

    @Test func sendMessageSetsErrorMessageOnFailure() async throws {
        let (vm, _, msgRepo, _) = makeVM()
        msgRepo.shouldThrowError = MessageError.sendFailed(underlying: nil)
        msgRepo.errorOnMethod = .insert
        await vm.loadMessages()
        await vm.sendMessage(text: "Hello")
        #expect(vm.errorMessage != nil)
        #expect(vm.errorMessage == MessageError.sendFailed(underlying: nil).localizedDescription)
    }

    @Test func sendMessageSetsErrorWhenChatUpdateFails() async throws {
        let (vm, chatRepo, _, _) = makeVM()
        chatRepo.shouldThrowError = ChatError.updateFailed(underlying: nil)
        chatRepo.errorOnMethod = .update
        await vm.loadMessages()
        await vm.sendMessage(text: "Hello")
        #expect(vm.errorMessage != nil)
        #expect(vm.errorMessage == ChatError.updateFailed(underlying: nil).localizedDescription)
    }

    @Test func commitTitleEditSetsErrorMessageOnFailure() async throws {
        let (vm, chatRepo, _, _) = makeVM()
        chatRepo.shouldThrowError = ChatError.updateFailed(underlying: nil)
        chatRepo.errorOnMethod = .update
        await vm.loadMessages()
        await vm.commitTitleEdit(newTitle: "New Title")
        #expect(vm.errorMessage != nil)
        #expect(vm.errorMessage == ChatError.updateFailed(underlying: nil).localizedDescription)
    }

    @Test func dismissErrorClearsErrorMessage() async throws {
        let (vm, _, msgRepo, _) = makeVM()
        msgRepo.shouldThrowError = MessageError.sendFailed(underlying: nil)
        msgRepo.errorOnMethod = .insert
        await vm.loadMessages()
        await vm.sendMessage(text: "Hello")
        #expect(vm.errorMessage != nil)
        vm.dismissError()
        #expect(vm.errorMessage == nil)
    }

    // MARK: - Pagination

    @Test func loadMessagesLoadsFirstPage() async throws {
        let (vm, _, msgRepo, _) = makeVM()
        // 20 messages; pageSize=15 → loads last 15 (m5–m19)
        msgRepo.messagesByChat["c1"] = (0..<20).map {
            Message(id: "m\($0)", chatId: "c1", text: "msg \($0)", type: .text, file: nil, sender: .user, timestamp: Int64($0))
        }
        await vm.loadMessages()
        #expect(vm.messages.messages.count == 15)
        #expect(vm.messages.messages.first?.id == "m5")
        #expect(vm.messages.messages.last?.id == "m19")
    }

    @Test func hasMoreMessagesFalseWhenUnderPageSize() async throws {
        let (vm, _, msgRepo, _) = makeVM()
        msgRepo.messagesByChat["c1"] = (0..<10).map {
            Message(id: "m\($0)", chatId: "c1", text: "msg \($0)", type: .text, file: nil, sender: .user, timestamp: Int64($0))
        }
        await vm.loadMessages()
        #expect(vm.messages.hasMoreMessages == false)
    }

    @Test func hasMoreMessagesTrueWhenFullPageReturned() async throws {
        let (vm, _, msgRepo, _) = makeVM()
        msgRepo.messagesByChat["c1"] = (0..<15).map {
            Message(id: "m\($0)", chatId: "c1", text: "msg \($0)", type: .text, file: nil, sender: .user, timestamp: Int64($0))
        }
        await vm.loadMessages()
        #expect(vm.messages.hasMoreMessages == true)
    }

    @Test func loadOlderMessagesPrependsOlderPage() async throws {
        let (vm, _, msgRepo, _) = makeVM()
        // 25 messages: initial load gets last 15 (m10–m24)
        msgRepo.messagesByChat["c1"] = (0..<25).map {
            Message(id: "m\($0)", chatId: "c1", text: "msg \($0)", type: .text, file: nil, sender: .user, timestamp: Int64($0))
        }
        await vm.loadMessages()
        #expect(vm.messages.messages.count == 15)
        #expect(vm.messages.messages.first?.timestamp == 10)

        vm.loadOlderMessages()
        try await Task.sleep(for: .milliseconds(1100)) // wait for 1s debounce + execution
        // Should prepend 10 older messages (m0–m9)
        #expect(vm.messages.messages.count == 25)
        #expect(vm.messages.messages.first?.timestamp == 0)
    }

    @Test func loadOlderMessagesSetsHasMoreFalseWhenExhausted() async throws {
        let (vm, _, msgRepo, _) = makeVM()
        // 20 messages: initial load gets last 15; one older page of 5 exhausts all
        msgRepo.messagesByChat["c1"] = (0..<20).map {
            Message(id: "m\($0)", chatId: "c1", text: "msg \($0)", type: .text, file: nil, sender: .user, timestamp: Int64($0))
        }
        await vm.loadMessages()
        vm.loadOlderMessages()
        try await Task.sleep(for: .milliseconds(1100))
        #expect(vm.messages.hasMoreMessages == false)
    }
}
