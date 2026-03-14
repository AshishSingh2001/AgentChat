# Problems Identified (Enriched)

## Architecture

### 1. Inconsistent Use Case Usage

**Current State:**
- `CreateChatUseCase` exists at `Features/ChatList/UseCases/CreateChatUseCase.swift` (lines 3-18)
- Delete logic is inline in `ChatListViewModel.swift:34-38`:

```swift
func deleteChat(_ chat: Chat) async {
    chats.removeAll { $0.id == chat.id }
    try? await chatRepository.delete(id: chat.id)
    try? await messageRepository.deleteAll(for: chat.id)
}
```

**Problem:** This inconsistency means:
- Create is testable via use case
- Delete is not (logic mixed with ViewModel's `chats` array manipulation)
- Other chat operations might also be inconsistent

---

### 2. Agent Architecture Issues

**Current Implementation:**

The decision logic is in `SimulateAgentReplyUseCase.swift:22-34`:
```swift
func decide(userMessageCount: Int, using rng: inout some RandomNumberGenerator) -> AgentReplyDecision
```

But the execution happens in `ChatDetailViewModel.swift:118-176` in `scheduleAgentReply()`:

```swift
// Line 155 - ViewModel directly inserts to DB!
try? await messageRepository.insert(agentMessage)

// Line 171 - ViewModel directly updates chat!
try? await chatRepository.update(updatedChat)
```

**Problems:**
- ViewModel is doing DB writes that should be in a service layer
- Agent is "pushed" from ViewModel rather than "pulled" from DB observation
- No `Data/Agents/` folder exists - agent logic is in feature folder
- The agent isn't truly external - it's tightly coupled to the ViewModel lifecycle

---

### 3. NotificationCenter Coupling

**Current Flow:**

In `PersistenceController.swift:35-37`:
```swift
await MainActor.run {
    NotificationCenter.default.post(name: .seedDataLoaded, object: nil)
}
```

In `ChatListView.swift:65-67`:
```swift
.onReceive(NotificationCenter.default.publisher(for: .seedDataLoaded)) { _ in
    Task { await viewModel.loadChats() }
}
```

**Problems:**
- `Notification.Name.seedDataLoaded` defined in `PersistenceController.swift:42-44`
- View is directly subscribing to persistence events
- Violates "View should only talk to ViewModel" principle
- No other use of NotificationCenter in the app - this is an anomaly

---

## Database

### 4. DB Initialization is Fire-and-Forget

**Current in `AgentChatApp.swift:17-20`:**
```swift
.onAppear {
    let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting-reset")
    persistence.seedInBackground(resetForTesting: isUITesting)
}
```

**In `PersistenceController.swift:25-39`:**
```swift
func seedInBackground(resetForTesting: Bool = false) {
    Task.detached {  // Fire-and-forget!
        let seeder = SeedDataLoader(modelContainer: container)
        try? await seeder.loadIfNeeded()
        await MainActor.run {
            NotificationCenter.default.post(name: .seedDataLoaded, object: nil)
        }
    }
}
```

**Problems:**
- App doesn't wait for seed to complete
- User might see empty chat list even though seed data exists
- The notification is a workaround for async initialization

---

### 5. No Schema Versioning

**Current in `PersistenceController.swift:15`:**
```swift
container = try ModelContainer(for: ChatEntity.self, MessageEntity.self)
```

**Problems:**
- No `VersionedSchema` implementation
- Entities at `Data/ChatEntity.swift` and `Data/MessageEntity.swift` not versioned
- When adding fields later, migration will be manual/hard
- No `Data/Schema/` folder exists

---

### 6. Repository Doesn't Block on Init

**Current in `SwiftDataChatRepository.swift:6-12`:**
```swift
func fetchAll() async throws -> [Chat] {
    let descriptor = FetchDescriptor<ChatEntity>(
        sortBy: [SortDescriptor(\.lastMessageTimestamp, order: .reverse)]
    )
    let entities = try modelContext.fetch(descriptor)
    return entities.map { $0.toChat() }
}
```

**Problems:**
- No check if seed has completed
- If called immediately after app launch, might return empty
- No `get()` function that blocks until ready

---

## Data Models

### 7. Message Model Doesn't Track Sync State

**Current `Message.swift` at `Domain/Message.swift:35-50`:**
```swift
struct Message: Identifiable, Hashable, Sendable {
    let id: String
    let chatId: String
    let text: String
    let type: MessageType
    let file: FileAttachment?
    let sender: Sender
    let timestamp: Int64
    
    // No syncState field!
}
```

**In `ChatDetailViewModel.swift:110`:**
```swift
messages.append(message)  // Optimistic - added immediately
// ... then later:
try? await messageRepository.insert(agentMessage)  // DB write
```

**Problems:**
- When DB listener fires, no way to know if message is already displayed
- Deduplication requires checking by ID (fragile)
- If DB write fails, UI shows ghost message

---

### 8. Domain/Entity Separation

**Domain (`Domain/Chat.swift`):**
```swift
struct Chat: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let lastMessage: String
    let lastMessageTimestamp: Int64
    let createdAt: Int64
    let updatedAt: Int64
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
```

**Entity (`Data/ChatEntity.swift`):**
```swift
@Model final class ChatEntity {
    @Relationship(deleteRule: .cascade, inverse: \MessageEntity.chat)
    var messages: [MessageEntity] = []
    // Conversion methods:
    func toChat() -> Chat { ... }
    static func from(_ chat: Chat) -> ChatEntity { ... }
}
```

**Problems:**
- Custom `Hashable` might be redundant with SwiftData
- Conversion methods add ~20 lines per model
- Could use `@Model` directly in domain but couples to SwiftData

---

## Messaging

### 9. Attachment Logic in ViewModel

**Current in `ChatDetailViewModel.swift:253-271`:**
```swift
func sendWithAttachment() async {
    guard let attachment = pendingAttachment else { return }
    pendingAttachment = nil
    
    let filename = UUID().uuidString + ".jpg"
    // File storage logic inline:
    guard let savedPath = try? fileStorageService.save(data: attachment.data, filename: filename) else { return }
    
    // Thumbnail generation inline:
    let thumbnailData = try? fileStorageService.generateThumbnail(from: attachment.data, maxWidth: 150)
    var thumbnailPath: String? = nil
    if let thumbData = thumbnailData {
        thumbnailPath = try? fileStorageService.save(data: thumbData, filename: "thumb_" + filename)
    }
    
    let fileAttachment = FileAttachment(...)
    await sendMessage(text: draftText, file: fileAttachment)
}
```

**Problems:**
- Not testable without mocking file system
- No `SendAttachmentMessageUseCase` exists
- `FileStorageService` at `Services/FileStorageService.swift` is injected but logic is in VM

---

### 10. Draft Saving Not Debounced

**Current in `ChatDetailViewModel.swift:14-17`:**
```swift
var draftText: String = "" {
    didSet {
        saveDraftText()  // Called on EVERY keystroke!
    }
}
```

**Save function at lines 89-94:**
```swift
private func saveDraftText() {
    if draftText.isEmpty {
        UserDefaults.standard.removeObject(forKey: draftKey)
    } else {
        UserDefaults.standard.set(draftText, forKey: draftKey)
    }
}
```

**Problems:**
- No debounce - every character triggers UserDefaults write
- No explicit save in `ChatDetailView.onDisappear`
- Draft could be lost if app killed mid-typing
- Key pattern at line 41: `"agentchat.draft.\(chatId)"` - scattered across files

---

## UI/UX

### 11. No Loading State in ChatList

**Current in `ChatListView.swift:20-27`:**
```swift
if viewModel.chats.isEmpty {
    ContentUnavailableView(
        "No Conversations",
        systemImage: "bubble.left.and.bubble.right",
        description: Text("Tap the compose button to start a chat")
    )
} else {
    List { ... }
}
```

**In `ChatListViewModel.swift:24-26`:**
```swift
func loadChats() async {
    chats = (try? await chatRepository.fetchAll()) ?? []
}
```

**Problems:**
- No `isLoading` state in ViewModel
- Can't differentiate "loading" from "empty"
- `ContentUnavailableView` shown during load

---

### 12. Scroll Behavior

**Current in `ChatDetailViewModel.swift:178-189`:**
```swift
func updateScrollOffset(_ offsetFromBottom: CGFloat) {
    isNearBottom = offsetFromBottom < 150
}

private func handleNewMessage() {
    if isNearBottom {
        shouldScrollToBottom = true
    } else {
        showNewMessageToast = true
        scheduleToastDismiss()
    }
}
```

**Problems:**
- Constants like `150` and `3` seconds are magic numbers
- Toast button tap to scroll not implemented
- May need more testing

---

## Testing

### 13. Missing Test Coverage

**What exists:**
- `Domain/ChatTests.swift`, `MessageTests.swift`
- `CreateChatUseCaseTests.swift`
- `ChatListViewModelTests.swift`, `ChatDetailViewModelTests.swift`
- Repository tests for CRUD
- FileStorageService tests

**What's missing (from next_steps.md:19-25):**
- ImageViewer actions (share, save)
- Invalid URL handling in image loading
- Full InputBar attachment flow testing
- ChatDetail attachment sheet and title edit sheet
- Message scroll behavior tests

---

### 14. SDWebImageSwiftUI in Coverage

**Problem:**
- `AgentChatUITests/` likely runs with coverage
- Third-party library shouldn't be in coverage reports

---

## Documentation

### 15. No Testing Documentation

**Current state:**
- No `docs/` folder
- No `testing.md`
- Edge cases not documented

---

## Performance

### 16. No Performance Profiling

**What we don't know:**
- Cold start time with seed
- FetchDescriptor query performance
- Memory usage with many messages
- No pagination strategy

---

## Summary

| # | Category | Problem | Key Files |
|---|----------|---------|-----------|
| 1 | Architecture | Inconsistent use cases | ChatListViewModel.swift:34-38 |
| 2 | Architecture | Agent in ViewModel | ChatDetailViewModel.swift:118-176 |
| 3 | Architecture | NotificationCenter coupling | PersistenceController.swift:36, ChatListView.swift:65 |
| 4 | Database | Fire-and-forget init | PersistenceController.swift:25-39 |
| 5 | Database | No schema versioning | PersistenceController.swift:15 |
| 6 | Database | No blocking fetch | SwiftDataChatRepository.swift:6-12 |
| 7 | Data Models | No sync state | Domain/Message.swift:35-50 |
| 8 | Data Models | Domain/entity overhead | Domain/ vs Data/ folders |
| 9 | Messaging | Attachment in VM | ChatDetailViewModel.swift:253-271 |
| 10 | Messaging | No debounce | ChatDetailViewModel.swift:14-17 |
| 11 | UI/UX | No loading state | ChatListViewModel.swift:24-26 |
| 12 | UI/UX | Scroll needs testing | ChatDetailViewModel.swift:178-189 |
| 13 | Testing | Coverage gaps | next_steps.md:19-25 |
| 14 | Testing | 3rd party in coverage | AgentChatUITests/ |
| 15 | Docs | No testing.md | - |
| 16 | Performance | No profiling | - |
