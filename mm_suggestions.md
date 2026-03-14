# Suggestions (Solutions)

## Architecture

### 1. DeleteChatUseCase

- [ ] Create `Features/ChatList/UseCases/DeleteChatUseCase.swift`
- [ ] Move deletion logic from `ChatListViewModel.deleteChat()` to use case
- [ ] Inject `chatRepository` and `messageRepository` dependencies

```swift
struct DeleteChatUseCase {
    let chatRepository: any ChatRepositoryProtocol
    let messageRepository: any MessageRepositoryProtocol

    func execute(chat: Chat) async throws {
        try await chatRepository.delete(id: chat.id)
        try await messageRepository.deleteAll(for: chat.id)
    }
}
```

---

### 2. Agent Architecture Refactor

- [ ] Create `Data/Agents/AgentService.swift` - separate agent service layer
- [ ] AgentService subscribes to message inserts (or receives trigger)
- [ ] AgentService directly writes to messageRepository and chatRepository
- [ ] Remove agent logic from `ChatDetailViewModel.scheduleAgentReply()`
- [ ] ViewModel observes DB changes instead

```swift
// Data/Agents/AgentService.swift
actor AgentService {
    private let messageRepository: any MessageRepositoryProtocol
    private let chatRepository: any ChatRepositoryProtocol
    
    func onUserMessageSent(_ message: Message) async {
        // Decide if agent should reply
        let decision = simulateAgentReply(userMessageCount: ...)
        
        // Create and insert agent message directly
        try? await messageRepository.insert(agentMessage)
        try? await chatRepository.update(chat)
    }
}
```

- [ ] Create `Data/Agents/` folder

---

### 3. Remove NotificationCenter

- [ ] Remove `NotificationCenter.default.post(name: .seedDataLoaded, ...)` from PersistenceController
- [ ] Remove `.onReceive(NotificationCenter...)` from ChatListView
- [ ] Remove `extension Notification.Name` in PersistenceController
- [ ] View loads data via ViewModel without needing notifications

---

## Database

### 4 & 6. DB Initialization Blocking

- [ ] Add `get()` function in PersistenceController that awaits initialization
- [ ] Make repositories block until DB is ready

```swift
// In PersistenceController
func get() async -> (chatRepository: ChatRepository, messageRepository: MessageRepository) {
    await databaseInitializer.ensureInitialized()
    return (chatRepository, messageRepository)
}

// DatabaseInitializer actor
actor DatabaseInitializer {
    private var isInitialized = false
    
    func ensureInitialized() async {
        if isInitialized { return }
        let seeder = SeedDataLoader(modelContainer: container)
        try? await seeder.loadIfNeeded()
        isInitialized = true
    }
}
```

- [ ] Remove `seedInBackground()` and fire-and-forget behavior
- [ ] Update `AgentChatApp.swift` to use blocking initialization

---

### 5. VersionedSchema

- [ ] Create `Data/Schema/AgentChatSchema.swift` with VersionedSchema
- [ ] Move entities to `Data/Schema/`
- [ ] Use schema in ModelContainer

```swift
enum AgentChatSchema: VersionedSchema {
    static var models: [any PersistentModel.Type] {
        [ChatEntity.self, MessageEntity.self]
    }
    
    static var schemaIdentifier: String { "AgentChatSchema" }
    
    enum V1: CodableSchema {
        static var identifier: String { "v1" }
    }
}
```

- [ ] Create `Data/Repositories/` folder for repositories

---

## Data Models

### 7. Message Sync State

- [ ] Add `syncState` to Message model in Domain/Message.swift

```swift
enum SyncState: String, Sendable {
    case pending   // Local only, not yet in DB
    case synced    // Confirmed in DB
    case failed    // Failed to sync
}

struct Message: Identifiable, Hashable, Sendable {
    let id: String
    // ... existing fields ...
    var syncState: SyncState = .synced
}
```

- [ ] When sending optimistically, set `syncState = .pending`
- [ ] On DB insert success, update to `.synced`
- [ ] On DB insert failure, update to `.failed` and handle rollback

---

### 8. Domain/Entity Separation

- [ ] Keep current separate approach (recommended for clean architecture)
- [ ] Optionally simplify Hashable - SwiftData may auto-synthesize

---

## Messaging

### 9. SendAttachmentMessageUseCase

- [ ] Create `Features/ChatDetail/UseCases/SendAttachmentMessageUseCase.swift`
- [ ] Move file storage, thumbnail generation logic from ViewModel
- [ ] Inject `FileStorageService` dependency

```swift
struct SendAttachmentMessageUseCase {
    let fileStorageService: FileStorageService
    let messageRepository: any MessageRepositoryProtocol
    let chatRepository: any ChatRepositoryProtocol
    
    func execute(attachment: PendingAttachment, draftText: String, chat: Chat) async throws -> Message {
        // Save file, generate thumbnail
        // Create message
        // Insert to DB
    }
}
```

- [ ] Update `ChatDetailViewModel` to use the new use case

---

### 10. Debounced Draft Saving

- [ ] Add debounce (300-500ms) to draft saving using task(id:)

```swift
private var draftSaveTask: Task<Void, Never>?

var draftText: String = "" {
    didSet {
        draftSaveTask?.cancel()
        draftSaveTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            saveDraftText()
        }
    }
}
```

- [ ] Add explicit save on `.onDisappear` in ChatDetailView

```swift
.onDisappear {
    viewModel.saveDraftImmediately()
}
```

---

## UI/UX

### 11. Loading State

- [ ] Add `isLoading: Bool` to `ChatListViewModel`

```swift
var isLoading = false

func loadChats() async {
    isLoading = true
    chats = (try? await chatRepository.fetchAll()) ?? []
    isLoading = false
}
```

- [ ] Show `ProgressView()` in ChatListView while loading

```swift
if viewModel.isLoading {
    ProgressView()
} else if viewModel.chats.isEmpty {
    ContentUnavailableView(...)
} else {
    List { ... }
}
```

- [ ] Add `isLoading` to `ChatDetailViewModel` if needed

---

### 12. Scroll Behavior

- [ ] Add "Scroll to bottom" button functionality
- [ ] Make toast tappable to scroll down
- [ ] Extract magic numbers to constants

---

## Testing

### 13. Missing Test Coverage

- [ ] Add ImageViewer action tests (share, save)
- [ ] Add invalid URL test in seed data
- [ ] Add full InputBar attachment flow tests
- [ ] Add ChatDetail attachment sheet tests
- [ ] Add title edit sheet tests
- [ ] Add message scroll behavior tests

### 14. SDWebImageSwiftUI

- [ ] Add exclusion in test scheme or xcconfig for SDWebImageSwiftUI

---

## Documentation

### 15. Testing Docs

- [ ] Create `/docs/` folder
- [ ] Create `docs/testing.md` with edge cases covered per file
- [ ] Create `docs/architecture.md` with folder structure and patterns

---

## Performance

### 16. Profiling

- [ ] Profile app cold start time
- [ ] Profile DB query performance
- [ ] Add pagination for chat list if needed (>100 chats)
- [ ] Consider lazy loading for messages
