# AgentChat — Master Implementation Plan
> Updated after Opus review. See FEEDBACK.md for rationale on every change.

## Architecture: Clean Architecture + MVVM

### Layers (dependency direction: inward only)

```
Presentation (Views + ViewModels)  — @MainActor
    ↓ depends on
Domain (UseCases + Models + Repository Protocols)  — pure Swift, no frameworks
    ↓ depends on
Data (SwiftData Entities + Concrete Repositories)  — @ModelActor
```

### Key Principles
- ViewModels are `@Observable` + `@MainActor` — own all UI state and async Task lifecycle
- Use cases are **stateless** — pure decision logic only, no timers, no Tasks
- Use cases exist only when there is real orchestration; pass-throughs are dropped
- Domain models are **plain Swift structs** — no `@Model` annotation
- Concrete repositories use `@ModelActor` — SwiftData's built-in actor for safe context access
- `ModelContext` never crosses actor boundaries — only domain structs do
- All navigation goes through `AppRouter` (injected via `.environment`)
- `NavigationPath` + `AppRoute` enum drives screen navigation — fully deep-linkable
- Image viewer is modal (`.fullScreenCover`) — not a NavigationPath push
- Tests inject mock repositories / mock use cases — nothing touches SwiftData in unit tests
- ChatList ↔ ChatDetail sync via `.task(id: router.path.count)` re-fetch on navigation pop

### Concurrency Model

```
@ModelActor SwiftDataChatRepository
    calls ModelContext (safe — same actor)
    returns [Chat] (Sendable structs — safe to cross actor boundary)

@MainActor ChatListViewModel
    calls await chatRepository.fetchAll()
    (Swift bridges @MainActor → @ModelActor automatically via async call)
```

Domain structs (`Chat`, `Message`) must conform to `Sendable` — verified at compile time.

---

## Folder Structure

```
AgentChat/
├── App/
│   ├── AgentChatApp.swift          # ModelContainer setup, DI wiring
│   └── AppView.swift               # NavigationStack + all navigationDestinations
│
├── Navigation/
│   ├── AppRoute.swift              # Hashable enum: .chatDetail(chatId:) only
│   └── AppRouter.swift             # @Observable @MainActor, path: NavigationPath
│
├── Features/
│   ├── ChatList/
│   │   ├── UseCases/
│   │   │   └── CreateChatUseCase.swift      # generates UUID + defaults, returns Chat
│   │   ├── ChatListView.swift
│   │   ├── ChatListViewModel.swift          # owns: chats[], deletion state
│   │   └── ChatRowView.swift
│   │
│   ├── ChatDetail/
│   │   ├── UseCases/
│   │   │   ├── SendMessageUseCase.swift         # insert + update chat metadata + auto-title
│   │   │   └── SimulateAgentReplyUseCase.swift  # pure: should reply? what type/content?
│   │   ├── ChatDetailView.swift
│   │   ├── ChatDetailViewModel.swift        # owns: messages[], debounce Task, scroll state, draft
│   │   ├── MessageListView.swift
│   │   ├── MessageBubbleView.swift
│   │   ├── ImageMessageView.swift
│   │   └── InputBarView.swift
│   │
│   └── ImageViewer/
│       └── ImageViewerView.swift            # .fullScreenCover, pinch-to-zoom
│
├── Domain/                         # Pure Swift — zero UIKit/SwiftData imports
│   ├── Chat.swift                  # struct Chat: Identifiable, Hashable, Sendable
│   ├── Message.swift               # struct Message + enums + FileAttachment — all Sendable
│   ├── ChatRepositoryProtocol.swift
│   └── MessageRepositoryProtocol.swift
│
├── Data/                           # SwiftData layer
│   ├── ChatEntity.swift            # @Model class + toChat() / from(_:) mappers
│   ├── MessageEntity.swift         # @Model class + @Relationship cascade delete
│   ├── SwiftDataChatRepository.swift    # @ModelActor final class
│   ├── SwiftDataMessageRepository.swift # @ModelActor final class
│   └── SeedDataLoader.swift        # first-launch seed: 3 chats + messages for all 3
│
├── Services/
│   ├── FileStorageServiceProtocol.swift
│   └── FileStorageService.swift    # Documents/AgentChat/attachments/ + thumbnails
│
└── Utilities/
    └── TimestampFormatter.swift    # relativeString(from:) + timeString(from:)
```

### Test Structure

```
AgentChatTests/
├── Mocks/
│   ├── MockChatRepository.swift       # shared across all test files
│   ├── MockMessageRepository.swift
│   ├── MockAppRouter.swift
│   └── MockFileStorageService.swift
├── Features/
│   ├── ChatList/
│   │   ├── CreateChatUseCaseTests.swift
│   │   └── ChatListViewModelTests.swift
│   └── ChatDetail/
│       ├── SendMessageUseCaseTests.swift
│       ├── SimulateAgentReplyUseCaseTests.swift
│       └── ChatDetailViewModelTests.swift
├── Navigation/
│   └── AppRouterTests.swift
├── Domain/
│   ├── ChatTests.swift
│   └── MessageTests.swift
└── Utilities/
    └── TimestampFormatterTests.swift
```

---

## Phases

---

### Phase 1 — Project Setup
**Goal:** Clean slate, dependencies in, folder structure created, project compiles.

**Steps:**
1. Add `SDWebImageSwiftUI` Swift Package
2. Delete boilerplate: `Item.swift`, `ContentView.swift`
3. Create all folders matching the structure above
4. Verify build passes

**Milestone M1 — Scaffold compiles:** `xcodebuild` succeeds with no source errors.

---

### Phase 2 — Domain Layer
**Goal:** Pure Swift models and repository interfaces. No frameworks. Fully `Sendable`.

#### Step 2.1 — Domain Models (TDD)
Write tests first in `Domain/ChatTests.swift` and `Domain/MessageTests.swift`:
- `Chat` initializes with correct field defaults
- `Chat` equality is ID-based (`Hashable` via `id`)
- `Message` with `.file` type requires non-nil `file` attachment
- `Message` with `.text` type has nil `file`
- `MessageType` and `Sender` enums have correct `String` raw values
- Millisecond timestamps store without precision loss
- `FileAttachment` computes display size: `245680` → `"240 KB"`, `1_200_000` → `"1.1 MB"`

Then implement:
- `Domain/Chat.swift` — `struct Chat: Identifiable, Hashable, Sendable`
- `Domain/Message.swift` — `struct Message: Identifiable, Hashable, Sendable`, `enum MessageType: String, Sendable`, `enum Sender: String, Sendable`, `struct FileAttachment: Sendable`

#### Step 2.2 — Repository Protocols
Both protocols are `actor`-compatible — their methods are `async throws` so callers can bridge actor contexts safely.

- `Domain/ChatRepositoryProtocol.swift`:
  ```swift
  protocol ChatRepositoryProtocol: Actor {
      func fetchAll() async throws -> [Chat]
      func create(_ chat: Chat) async throws
      func update(_ chat: Chat) async throws
      func delete(id: String) async throws
  }
  ```
- `Domain/MessageRepositoryProtocol.swift`:
  ```swift
  protocol MessageRepositoryProtocol: Actor {
      func fetchMessages(for chatId: String) async throws -> [Message]
      func insert(_ message: Message) async throws
      func deleteAll(for chatId: String) async throws
  }
  ```

**Milestone M2 — Domain complete:** All domain model tests pass. Protocols compile. Zero SwiftData/UIKit imports in `Domain/`.

---

### Phase 3 — Data Layer
**Goal:** SwiftData entities + `@ModelActor` repositories. Testable via in-memory `ModelContainer`.

#### Step 3.1 — SwiftData Entities
- `Data/ChatEntity.swift` — `@Model final class ChatEntity`; `toChat() -> Chat` and `static func from(_ chat: Chat, context: ModelContext) -> ChatEntity` mappers
- `Data/MessageEntity.swift` — same pattern; `@Relationship(deleteRule: .cascade)` on messages from ChatEntity

#### Step 3.2 — Repositories (TDD)
Write tests using an in-memory `ModelContainer` created in `setUp`:
```swift
let container = try ModelContainer(
    for: ChatEntity.self, MessageEntity.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
)
```

Test cases:
- `fetchAll()` returns chats sorted by `lastMessageTimestamp` descending
- `create()` persists and is queryable in same context
- `delete(id:)` removes chat
- `insert(_ message:)` persists message and updates parent `Chat.lastMessage` + `updatedAt`
- `fetchMessages(for:)` returns messages in ascending timestamp order

Then implement, marking each class `@ModelActor`:
```swift
@ModelActor
final class SwiftDataChatRepository: ChatRepositoryProtocol { ... }

@ModelActor
final class SwiftDataMessageRepository: MessageRepositoryProtocol { ... }
```

`@ModelActor` automatically creates an actor bound to the `ModelContext` — no manual context passing needed.

#### Step 3.3 — Seed Data (TDD)
Write tests:
- `SeedDataLoader.loadIfNeeded()` inserts exactly 3 chats on first call
- Chat 1 gets 10 messages (from assignment spec)
- Chats 2 and 3 each get 5-8 generated messages (so they're not empty on reviewer tap)
- Calling again (flag already set) is a no-op

Then implement `Data/SeedDataLoader.swift` — checks `UserDefaults["agentchat.seedLoaded"]`.

**Milestone M3 — Data layer complete:** Repository tests pass. Seed verified.

---

### Phase 4 — Services & Utilities
**Goal:** All cross-feature services tested and implemented.

#### Step 4.1 — TimestampFormatter (TDD)
Two explicit methods, two sets of tests:

`relativeString(from:)` — for chat list rows:
- `< 60s` → `"Just now"`
- `2 min ago` → `"2m ago"`
- `today, earlier` → `"10:30 AM"`
- `yesterday` → `"Yesterday"`
- `this year, older` → `"Dec 20"`
- `last year` → `"Dec 20, 2023"`

`timeString(from:)` — for message bubble timestamps:
- Any time → `"2:30 PM"` (short time format)

#### Step 4.2 — FileStorageService (TDD)
Write tests using injected temp directory (not real `Documents`):
- `save(data:filename:)` writes to expected path and returns it
- `generateThumbnail(from:maxWidth:)` returns image ≤ `maxWidth` wide
- `formattedFileSize(bytes:)`: `245680` → `"240 KB"`, `1_200_000` → `"1.1 MB"`
- Saving same filename overwrites (idempotent)

Implement with injectable `baseURL` for testability:
```swift
final class FileStorageService: FileStorageServiceProtocol {
    let baseURL: URL  // injected; defaults to Documents/AgentChat/attachments/
    init(baseURL: URL = .defaultAttachmentsDirectory)
}
```

**Milestone M4 — Services complete:** Both formatter cases and file service tests pass.

---

### Phase 5 — Navigation + DI Shell
**Goal:** Router wired, `AppView` shell running, app launchable from this phase forward.

#### Step 5.1 — AppRoute + AppRouter (TDD)
Write tests:
- `router.push(.chatDetail(chatId: "x"))` → `path.count == 1`
- `router.pop()` → `path.count == 0`
- `router.popToRoot()` clears any depth
- Pushing same route twice → `path.count == 2`

Then implement:
- `Navigation/AppRoute.swift`:
  ```swift
  enum AppRoute: Hashable {
      case chatDetail(chatId: String)
      // Note: imageViewer is NOT here — it's a modal, not a push
  }
  ```
- `Navigation/AppRouter.swift` — `@Observable @MainActor final class AppRouter`

#### Step 5.2 — DI Shell (app must run after this step)
- `AgentChatApp.swift` — creates `ModelContainer`, initializes `@ModelActor` repositories, creates `AppRouter`, builds `AppView`
- `AppView.swift` — `NavigationStack(path: $router.path)` with `navigationDestination(for: AppRoute.self)`, passes DI to each destination's ViewModel at push time

At this point the app builds and launches showing an empty (or stubbed) chat list. Every phase after this is verified on-device.

**Milestone M5 — App is launchable:** Router tests pass. Simulator shows NavigationStack root.

---

### Phase 6 — ChatList Feature
**Goal:** Chat list screen fully functional.

#### Step 6.1 — CreateChatUseCase (TDD)
Mock `ChatRepository` injected. Tests:
- Creates `Chat` with a generated UUID (non-empty, unique across two calls)
- Sets `title` to `"New Chat"` placeholder
- Sets `createdAt` and `updatedAt` to current time
- Returns the created `Chat`

#### Step 6.2 — ChatListViewModel (TDD)
Tests with `MockChatRepository` + `MockAppRouter`:
- `chats` is empty on init, populated after `loadChats()`
- `createNewChat()` → creates chat, calls `router.push(.chatDetail(chatId:))`
- `deleteChat(_:)` → sets `chatPendingDeletion` state
- Confirming deletion → calls `repository.delete(id:)` + `messageRepository.deleteAll(for:)` + removes from `chats`
- Cancelling → leaves `chats` unchanged
- `loadChats()` called again after navigation pop (`.task(id: router.path.count)`) reflects latest data

#### Step 6.3 — ChatList UI
- `ChatListView.swift` — `List`, toolbar "New Chat" button, empty state, `.confirmationDialog` for delete, `.task(id: router.path.count)` for re-fetch
- `ChatRowView.swift` — title (bold), last message (2-line `lineLimit`, secondary color), `TimestampFormatter.relativeString(from:)` timestamp

**Milestone M6 — ChatList works on device:** Build + install + screenshot. List loads seed data. New chat navigates. Delete with confirm works.

---

### Phase 7 — ChatDetail Feature
**Goal:** Full chat conversation screen.

#### Step 7.1 — SendMessageUseCase (TDD)
Tests with `MockChatRepository` + `MockMessageRepository`:
- Inserts message via `messageRepository.insert`
- Updates `Chat.lastMessage` and `updatedAt` via `chatRepository.update`
- On first user message (no existing messages), sets chat title to first 30 chars of text
- Subsequent messages do not overwrite title
- Empty text + no file → throws or no-ops (defined behavior)

#### Step 7.2 — SimulateAgentReplyUseCase (TDD)
This use case is **pure and stateless**. It takes a counter and a seeded random source:
```swift
struct AgentReplyDecision {
    let shouldReply: Bool
    let replyType: ReplyType  // .text(String) or .image(URL)
}

func decide(userMessageCount: Int, using rng: inout some RandomNumberGenerator) -> AgentReplyDecision
```

Tests with fixed `RandomNumberGenerator` (deterministic):
- Counter at 4 with seeded rng → `shouldReply == false`
- Counter at 5 with seeded rng → `shouldReply == true`, type determined by 70/30 split
- All 5 predefined text responses appear in rotation
- Image URL is `https://picsum.photos/400/300`

No `Task`, no `sleep`, no timer — completely synchronous, trivially testable.

#### Step 7.3 — ChatDetailViewModel (TDD)
Tests with mock use cases + `MockAppRouter`:

**Messaging:**
- `sendMessage(text:)` calls `SendMessageUseCase`, appends to `messages`
- `sendMessage("")` is a no-op
- `sendMessage` increments internal `userMessageCount`
- After send, schedules agent reply: `Task.sleep(1-2s)` then calls `SimulateAgentReplyUseCase.decide`
- Rapid sends within 1.5s cancel the previous `Task` (store handle, call `.cancel()` on new send)

**Scroll state:**
- `isNearBottom` is `true` when `scrollOffsetFromBottom < 150`
- New message + `isNearBottom == true` → `shouldScrollToBottom = true`
- New message + `isNearBottom == false` → `showNewMessageToast = true`
- Toast auto-dismisses after 3s via a `Task` stored on ViewModel
- `dismissToast()` cancels the auto-dismiss task and clears toast

**Draft:**
- `draftText` changes persist to `UserDefaults["agentchat.draft.\(chatId)"]`
- On `init`, `draftText` restored from `UserDefaults`
- Sending clears draft key

**Title editing:**
- `startTitleEdit()` → `isTitleEditing = true`
- `commitTitleEdit(newTitle:)` → `chatRepository.update(chat with new title)` + `isTitleEditing = false`

#### Step 7.4 — ChatDetail UI
- `ChatDetailView.swift` — nav bar title tappable (shows `TextField` overlay when `isTitleEditing`)
- `MessageListView.swift` — `ScrollViewReader` + `LazyVStack`; `GeometryReader` inside scroll to measure offset for threshold; `NewMessageToastView` pill overlay (slide-up animation)
- `MessageBubbleView.swift` — `.leading`/`.trailing` alignment; user: blue bubble; agent: gray; `TimestampFormatter.timeString(from:)` below bubble
- `ImageMessageView.swift` — `WebImage` with placeholder spinner + error state; file size label; tap sets `viewModel.selectedImageForViewer` which triggers `.fullScreenCover`
- `InputBarView.swift` — `TextEditor` dynamic height (1–5 lines via `min/maxHeight`); send button disabled when empty; `PhotosPicker` + camera option; `safeAreaInset(edge: .bottom)`

**Milestone M7 — ChatDetail works on device:** Messages send, agent replies after delay, scroll toast appears, images load from URLs.

---

### Phase 8 — Image Features
**Goal:** Camera/gallery picking, local storage, fullscreen viewer with zoom.

#### Step 8.1 — Image Picker
- `PhotosPicker` (gallery) → on selection, load `Data`, call `FileStorageService.save` + `generateThumbnail`, build `Message` with `type: .file`
- Camera — `UIImagePickerController` wrapped in `UIViewControllerRepresentable`; same save flow
- Show pending image preview in `InputBarView` before send (confirm / discard)

#### Step 8.2 — ImageViewerView (with pinch-to-zoom)
Presented via `.fullScreenCover` on `ChatDetailView`, driven by `@State var selectedImageForViewer: ImageViewerItem?` on the ViewModel.

```swift
// Basic pinch-to-zoom
@State private var scale: CGFloat = 1.0
@State private var lastScale: CGFloat = 1.0

image
    .scaleEffect(scale)
    .gesture(
        MagnifyGesture()
            .onChanged { scale = lastScale * $0.magnification }
            .onEnded { lastScale = scale }
    )
```

Also: double-tap to reset scale to 1.0. `X` dismiss button top-right.

#### Step 8.3 — FileStorageService wiring
- Inject `FileStorageService` into `ChatDetailViewModel` via init DI
- Store `file.path` as relative path (filename only), resolve to absolute on display — portable across reinstalls

**Milestone M8 — Images complete:** Send gallery photo, agent sends picsum image, tap opens fullscreen with zoom.

---

### Phase 9 — Seed Data + End-to-End Verification
**Goal:** All DI is already wired (done in Phase 5). This phase verifies the full flow.

#### Step 9.1 — Seed completeness
- Chat 1: 10 messages from assignment spec (with 2 image messages)
- Chat 2 ("Hotel Reservation Help"): 6 generated messages, alternating user/agent, ending with assignment's `lastMessage`
- Chat 3 ("Restaurant Recommendations"): 5 generated messages, ending with assignment's `lastMessage`
- All `lastMessage` and `lastMessageTimestamp` values match the last seeded message in each chat

#### Step 9.2 — Full flow smoke test
- Cold launch → seeded chats appear instantly (no loading state)
- Tap Chat 1 → 10 messages in order, images load
- Send message → agent replies after 1-2s
- Scroll up past threshold → send message → toast appears → tap toast → scrolls to bottom
- Back → chat list shows updated `lastMessage`
- Create new chat → navigate to empty chat → send first message → title updates
- Delete chat with swipe → confirmation → gone from list

**Milestone M9 — End-to-end verified:** All flows work on device. Console logs confirm no errors.

---

### Phase 10 — Polish, Edge Cases & Deliverables
**Goal:** Shippable quality. All assignment deliverables present.

#### Step 10.1 — Empty states
- Chat list: centered empty state with "No conversations yet" and "Start a new chat" button
- Chat detail: centered "Send a message to begin" when `messages` is empty

#### Step 10.2 — Error & offline states
- Network image failure → SDWebImage error closure → gray broken-image icon + "Image unavailable" caption
- Agent image reply when offline → message inserted, `WebImage` shows error state naturally

#### Step 10.3 — Keyboard & layout
- Verify `safeAreaInset(edge: .bottom)` keeps input bar above keyboard on all screen sizes
- iPhone SE (375pt) — no clipping on bubbles or input bar
- iPhone 16 Pro Max — no excessive whitespace

#### Step 10.4 — README.md
Required deliverable. Include:
- App overview and screenshots
- Architecture diagram (text-based is fine)
- Setup instructions (clone → open → select simulator → run)
- Architecture decisions: Clean Architecture + MVVM, `@ModelActor` repositories, feature-first structure, 3 meaningful use cases
- Assumptions made (agent trigger logic, scroll threshold, etc.)
- TDD approach summary

#### Step 10.5 — Final build + recording
- Clean build, no warnings
- All test suites pass
- Screen recording: launch → seed chats → chat detail → send message → agent reply → send image → fullscreen image → back → delete chat

**Milestone M10 — Shippable:** No warnings, all tests pass, README written, recording captured.

---

## Milestones Summary

| # | Phase | Milestone |
|---|---|---|
| M1 | Phase 1 | Scaffold compiles, folder structure in place |
| M2 | Phase 2 | Domain models + Sendable structs + protocols, tests pass |
| M3 | Phase 3 | @ModelActor repositories + seed data, repo tests pass |
| M4 | Phase 4 | Formatter (both methods) + FileStorageService tested |
| M5 | Phase 5 | Router tested, **app launches on simulator** |
| M6 | Phase 6 | ChatList: load, create, delete — verified on device |
| M7 | Phase 7 | ChatDetail: messages, agent reply, scroll, draft — on device |
| M8 | Phase 8 | Image send/receive/fullscreen/zoom — on device |
| M9 | Phase 9 | Full end-to-end smoke test passes |
| M10 | Phase 10 | No warnings, all tests pass, README + recording |

---

## Commit Cadence

One commit per meaningful unit: test file addition, then implementation. Each commit should build cleanly. The history should read as a clear progression of the app being built.

Format: `<type>(<scope>): <description>`
Types: `feat` · `test` · `fix` · `chore` · `docs`
Scope: feature or layer name, e.g. `domain`, `chat-list`, `agent-reply`

### Phase 1 — Scaffold
```
chore(scaffold): add SDWebImageSwiftUI Swift Package
chore(scaffold): remove Item.swift and ContentView.swift boilerplate
chore(scaffold): create feature-first folder structure
```

### Phase 2 — Domain
```
test(domain): Chat and Message struct tests
feat(domain): Chat and Message Sendable domain models
feat(domain): ChatRepositoryProtocol and MessageRepositoryProtocol
```

### Phase 3 — Data
```
feat(data): ChatEntity and MessageEntity SwiftData models with mappers
test(data): SwiftDataChatRepository fetch, create, delete, cascade
feat(data): SwiftDataChatRepository @ModelActor implementation
test(data): SwiftDataMessageRepository insert, fetch, deleteAll
feat(data): SwiftDataMessageRepository @ModelActor implementation
test(data): SeedDataLoader first-launch and no-op behavior
feat(data): SeedDataLoader with seed messages for all 3 chats
```

### Phase 4 — Services & Utilities
```
test(utilities): TimestampFormatter relativeString and timeString
feat(utilities): TimestampFormatter
test(services): FileStorageService save, thumbnail, size formatting
feat(services): FileStorageService with injectable base URL
```

### Phase 5 — Navigation + DI Shell
```
test(navigation): AppRouter push, pop, popToRoot
feat(navigation): AppRoute enum and AppRouter
feat(app): AgentChatApp DI wiring and AppView NavigationStack shell
```

### Phase 6 — ChatList
```
test(chat-list): CreateChatUseCase generates UUID and defaults
feat(chat-list): CreateChatUseCase
test(chat-list): ChatListViewModel load, create, delete states
feat(chat-list): ChatListViewModel
feat(chat-list): ChatListView and ChatRowView
```

### Phase 7 — ChatDetail
```
test(chat-detail): SendMessageUseCase insert, update metadata, auto-title
feat(chat-detail): SendMessageUseCase
test(agent-reply): SimulateAgentReplyUseCase pure decision with injectable RNG
feat(agent-reply): SimulateAgentReplyUseCase
test(chat-detail): ChatDetailViewModel messaging, scroll state, draft, title edit
feat(chat-detail): ChatDetailViewModel
feat(chat-detail): ChatDetailView and MessageListView with scroll + toast
feat(chat-detail): MessageBubbleView and ImageMessageView
feat(chat-detail): InputBarView with dynamic height and attachment picker
```

### Phase 8 — Image Features
```
feat(image-viewer): ImageViewerView fullScreenCover with pinch-to-zoom
feat(image-picker): gallery and camera picker with FileStorageService wiring
```

### Phase 9 — End-to-End
```
feat(seed): complete seed messages for Hotel and Restaurant chats
fix(*): end-to-end integration fixes from smoke test
```

### Phase 10 — Polish
```
feat(ui): empty states for chat list and chat detail
fix(ui): offline image error state via SDWebImage error handler
fix(ui): keyboard safe area on iPhone SE and Pro Max
docs: README with architecture, setup instructions, and assumptions
```

**Total: ~30 commits.** The git log tells the full story of the app being built, test-first, layer by layer.

---

## Use Case Inventory (final — 3 only)

| Use Case | Kept | Reason |
|---|---|---|
| `CreateChatUseCase` | ✅ | Generates UUID, timestamps, default title |
| `SendMessageUseCase` | ✅ | Multi-step: insert + update chat + auto-title on first message |
| `SimulateAgentReplyUseCase` | ✅ (stateless) | Pure decision logic: should reply? what type? injectable RNG |
| `FetchChatsUseCase` | ❌ dropped | Pass-through; ViewModel calls repository directly |
| `FetchMessagesUseCase` | ❌ dropped | Pass-through |
| `DeleteChatUseCase` | ❌ dropped | One-liner; ViewModel calls repository directly |
| `UpdateChatTitleUseCase` | ❌ dropped | Folded into `SendMessageUseCase` (auto) + ViewModel (manual edit) |

---

## Confirmed Decisions (Reference)

| Concern | Decision |
|---|---|
| iOS target | iOS 26.2 · Simulator UDID: `3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC` |
| Persistence | SwiftData |
| Architecture | Clean Architecture + MVVM |
| Concurrency | ViewModels `@MainActor`, repositories `@ModelActor`, domain structs `Sendable` |
| ViewModels | `@Observable` — own UI state + async Task lifecycle |
| Use cases | Stateless, pure logic only — 3 total |
| Image loading | SDWebImageSwiftUI |
| Navigation | `NavigationPath` + `AppRoute` enum + `AppRouter` via `.environment` |
| Image viewer | `.fullScreenCover` (modal, not push) + pinch-to-zoom |
| ChatList sync | `.task(id: router.path.count)` re-fetches on nav pop |
| New chat flow | Tap → create → navigate → first user message auto-titles (≤30 chars) |
| Scroll UX | 150px threshold → auto-scroll; beyond → "↓ New message" pill toast, 3s auto-dismiss |
| Agent debounce | ViewModel cancels pending Task + resets counter on rapid send (<1.5s) |
| Agent reply logic | UseCase is pure (injectable RNG); ViewModel owns Task.sleep + cancellation |
| File storage | `Documents/AgentChat/attachments/` + UUID filename + ~150px thumbnail |
| Bonus features | Editable title (tap nav bar) + swipe-to-delete + draft saving |
| Seed data | Chat 1: 10 msgs (spec); Chats 2 & 3: 5-8 generated msgs each |
| Tests | Swift Testing framework, ViewModels + use cases + utilities, `Mocks/` folder |
| README | Required deliverable, added to Phase 10 |
