# Post-Build Improvement Plan

Ordered by severity. Each milestone = one commit.

---

## M1 — Debounce Draft Saving (perf bug)

**Severity:** HIGH — every keystroke triggers a synchronous `UserDefaults.set()`.

**Files to modify:**
- `AgentChat/Features/ChatDetail/ChatDetailViewModel.swift`
- `AgentChat/Features/ChatDetail/ChatDetailView.swift`

**What to do:**

1. In `ChatDetailViewModel`, replace the `didSet` on `draftText` with a debounced Task:
   - Remove the `didSet { saveDraftText() }` block.
   - Add a `private var draftSaveTask: Task<Void, Never>?` property.
   - Add a method `debouncedSaveDraft()` that cancels the previous task, creates a new Task that sleeps 300ms then calls `saveDraftText()` (checking `Task.isCancelled` after sleep).
   - Call `debouncedSaveDraft()` from wherever `draftText` changes — but since `@Observable` + `@Bindable` binding updates `draftText` directly, use `didSet` to call `debouncedSaveDraft()` instead of `saveDraftText()`.

2. Add a public `saveDraftImmediately()` method:
   ```swift
   func saveDraftImmediately() {
       draftSaveTask?.cancel()
       saveDraftText()
   }
   ```

3. In `ChatDetailView.swift`, add `.onDisappear { viewModel.saveDraftImmediately() }` to the root `VStack`.

4. In the existing `sendMessage()` method, after `draftText = ""`, the debounced save will fire but with empty text — that's fine (it calls `removeObject`). No change needed there.

**Tests:** The existing `ChatDetailViewModelTests` that test draft save/load should still pass. Add one test that verifies `saveDraftImmediately()` writes to UserDefaults.

**Commit:** `fix(draft): debounce draft saving to avoid per-keystroke UserDefaults writes`

---

## M2 — Loading State in ChatList (UX bug)

**Severity:** HIGH — user sees "No Conversations" empty state during async seed load, then it flickers to the actual list.

**Files to modify:**
- `AgentChat/Features/ChatList/ChatListViewModel.swift`
- `AgentChat/Features/ChatList/ChatListView.swift`

**What to do:**

1. In `ChatListViewModel`, add:
   ```swift
   var isLoading = true
   ```
   Set `isLoading = true` at the start of `loadChats()`, set `isLoading = false` after the fetch completes. Initialize to `true` so the first render shows a spinner.

2. In `ChatListView`, update the `Group` body:
   ```swift
   if viewModel.isLoading {
       ProgressView()
           .frame(maxWidth: .infinity, maxHeight: .infinity)
   } else if viewModel.chats.isEmpty {
       ContentUnavailableView(...)
   } else {
       List { ... }
   }
   ```

**Tests:** Update `ChatListViewModelTests` — after `loadChats()` completes, assert `isLoading == false`. If there's a test that checks the empty state, make sure it calls `loadChats()` first.

**Commit:** `fix(chat-list): add loading state to prevent empty-state flash on launch`

---

## M3 — DeleteChatUseCase (architecture consistency)

**Severity:** MEDIUM — delete logic is inline in ViewModel while create has a use case. Inconsistent pattern.

**Files to create:**
- `AgentChat/Features/ChatList/UseCases/DeleteChatUseCase.swift`

**Files to modify:**
- `AgentChat/Features/ChatList/ChatListViewModel.swift`
- `AgentChat.xcodeproj/project.pbxproj` (add new file)

**Files to create (tests):**
- `AgentChatTests/Features/ChatList/DeleteChatUseCaseTests.swift`

**What to do:**

1. Create `DeleteChatUseCase`:
   ```swift
   import Foundation

   struct DeleteChatUseCase {
       let chatRepository: any ChatRepositoryProtocol
       let messageRepository: any MessageRepositoryProtocol

       func execute(chatId: String) async throws {
           try await messageRepository.deleteAll(for: chatId)
           try await chatRepository.delete(id: chatId)
       }
   }
   ```
   Note: delete messages first, then delete chat — order matters for data integrity (messages reference chat).

2. In `ChatListViewModel`:
   - Add `private let deleteChatUseCase: DeleteChatUseCase` property.
   - Initialize it in `init` from the injected repositories.
   - Replace `deleteChat(_:)` body:
     ```swift
     func deleteChat(_ chat: Chat) async {
         chats.removeAll { $0.id == chat.id }
         try? await deleteChatUseCase.execute(chatId: chat.id)
     }
     ```

3. Create `DeleteChatUseCaseTests`:
   - Test that calling `execute(chatId:)` invokes `messageRepository.deleteAll(for:)` and `chatRepository.delete(id:)`.
   - Use `MockChatRepository` and `MockMessageRepository` from `AgentChatTests/Mocks/`.

**Commit:** `refactor(chat-list): extract DeleteChatUseCase for consistency with CreateChatUseCase`

---

## M4 — SendAttachmentMessageUseCase (architecture / testability)

**Severity:** MEDIUM — file storage, thumbnail generation, and message construction all inline in ViewModel. Not testable without mocking the file system.

**Files to create:**
- `AgentChat/Features/ChatDetail/UseCases/SendAttachmentMessageUseCase.swift`

**Files to modify:**
- `AgentChat/Features/ChatDetail/ChatDetailViewModel.swift`
- `AgentChat.xcodeproj/project.pbxproj` (add new file)

**Files to create (tests):**
- `AgentChatTests/Features/ChatDetail/SendAttachmentMessageUseCaseTests.swift`

**What to do:**

1. Create `SendAttachmentMessageUseCase`:
   ```swift
   import Foundation

   struct SendAttachmentMessageUseCase {
       let fileStorageService: FileStorageService
       let sendMessageUseCase: SendMessageUseCase

       func execute(
           attachment: PendingAttachment,
           text: String,
           chat: Chat,
           existingMessageCount: Int
       ) async throws -> (message: Message, updatedChat: Chat) {
           let filename = UUID().uuidString + ".jpg"
           let savedPath = try fileStorageService.save(data: attachment.data, filename: filename)

           let thumbnailData = try? fileStorageService.generateThumbnail(from: attachment.data, maxWidth: 150)
           var thumbnailPath: String? = nil
           if let thumbData = thumbnailData {
               thumbnailPath = try? fileStorageService.save(data: thumbData, filename: "thumb_" + filename)
           }

           let fileAttachment = FileAttachment(
               path: savedPath,
               fileSize: Int64(attachment.data.count),
               thumbnailPath: thumbnailPath
           )

           return try await sendMessageUseCase.execute(
               text: text,
               file: fileAttachment,
               chat: chat,
               existingMessageCount: existingMessageCount
           )
       }
   }
   ```

2. In `ChatDetailViewModel`:
   - Add `private let sendAttachmentMessageUseCase: SendAttachmentMessageUseCase` initialized in `init`.
   - Simplify `sendWithAttachment()`:
     ```swift
     func sendWithAttachment() async {
         guard let attachment = pendingAttachment else { return }
         pendingAttachment = nil

         guard let (message, updatedChat) = try? await sendAttachmentMessageUseCase.execute(
             attachment: attachment,
             text: draftText.trimmingCharacters(in: .whitespaces),
             chat: chat,
             existingMessageCount: messages.count
         ) else { return }

         chat = updatedChat
         messages.append(message)
         userMessageCount += 1
         draftText = ""
         handleNewMessage()
         scheduleAgentReply(for: userMessageCount)
     }
     ```

3. Tests: Use `MockFileStorageService` (already exists in `AgentChatTests/Mocks/`). Test that execute saves file, generates thumbnail, and delegates to `SendMessageUseCase`.

**Commit:** `refactor(chat-detail): extract SendAttachmentMessageUseCase from ViewModel`

---

## M5 — Replace NotificationCenter + Fire-and-Forget Seed (architecture)

**Severity:** MEDIUM — NotificationCenter is an anomaly in the codebase; fire-and-forget seed means the repository can return empty during the seed window.

**Files to modify:**
- `AgentChat/App/PersistenceController.swift`
- `AgentChat/AgentChatApp.swift`
- `AgentChat/App/AppView.swift`
- `AgentChat/Features/ChatList/ChatListView.swift`
- `AgentChat/Features/ChatList/ChatListViewModel.swift`

**What to do:**

1. In `PersistenceController`, replace fire-and-forget with an awaitable pattern:
   - Add a `private(set) var isSeedComplete = false` property.
   - Replace `seedInBackground()` with `seed(resetForTesting:) async`:
     ```swift
     func seed(resetForTesting: Bool = false) async {
         let container = self.container
         await Task.detached {
             let seeder = SeedDataLoader(modelContainer: container)
             if resetForTesting {
                 UserDefaults.standard.removeObject(forKey: "agentchat.seedLoaded")
                 try? await seeder.resetAndReload()
             } else {
                 try? await seeder.loadIfNeeded()
             }
         }.value
         isSeedComplete = true
     }
     ```
   - Remove the `Notification.Name.seedDataLoaded` extension entirely.

2. In `AgentChatApp.swift`, change `.onAppear` to `.task`:
   ```swift
   .task {
       let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting-reset")
       await persistence.seed(resetForTesting: isUITesting)
   }
   ```
   This still doesn't block rendering — `.task` is async. The `ChatListViewModel.loadChats()` runs from `.task` in `ChatListView` which may fire before seed completes, but M2's loading state handles that.

3. In `ChatListView`:
   - Remove the `.onReceive(NotificationCenter.default.publisher(for: .seedDataLoaded))` modifier entirely.
   - The `.onChange(of: router.path.count)` and `.task { await viewModel.loadChats() }` already handle reloading.
   - To ensure data appears after seed, the simplest approach: add a brief delay-retry in `loadChats()` or rely on the `.task` modifier re-firing. Alternatively, keep `.task` and add a second `.task` that awaits a small delay then reloads:
     ```swift
     .task(id: viewModel.chats.isEmpty) {
         if viewModel.chats.isEmpty {
             try? await Task.sleep(for: .milliseconds(500))
             await viewModel.loadChats()
         }
     }
     ```
     This retries once if initial load found nothing (seed hadn't finished yet).

4. The loading state from M2 ensures the user sees a spinner, not "No Conversations", during this window.

**Important:** Run all 8 XCUITests after this change — the `testSeedChatsAppearOnLaunch` test has a 15s timeout so it should tolerate the async flow, but verify.

**Commit:** `refactor(persistence): replace NotificationCenter with awaitable seed initialization`

---

## M6 — Scroll Constants + Minor Polish (code quality)

**Severity:** LOW — magic numbers in scroll logic; minor polish items.

**Files to modify:**
- `AgentChat/Features/ChatDetail/ChatDetailViewModel.swift`

**What to do:**

1. Extract magic numbers to private constants at the top of `ChatDetailViewModel`:
   ```swift
   private enum Constants {
       static let scrollThreshold: CGFloat = 150
       static let toastDismissDelay: TimeInterval = 3
       static let draftDebounceDelay: Duration = .milliseconds(300)
   }
   ```

2. Replace `150` in `updateScrollOffset` with `Constants.scrollThreshold`.
3. Replace `.seconds(3)` in `scheduleToastDismiss` with `.seconds(Constants.toastDismissDelay)`.
4. Replace the debounce delay from M1 with `Constants.draftDebounceDelay`.

**Toast tap-to-scroll:** Already implemented in `MessageListView.swift:46-50` — the toast `Button` calls `proxy.scrollTo(lastId)` then `viewModel.dismissToast()`. No work needed here.

**Commit:** `refactor(chat-detail): extract magic numbers to constants`

---

## M7 — Additional Test Coverage (testing gaps)

**Severity:** LOW — existing coverage is 94 unit tests + 8 XCUITests, but some flows lack unit tests.

**Files to create:**
- `AgentChatTests/Features/ChatList/DeleteChatUseCaseTests.swift` (if not done in M3)
- `AgentChatTests/Features/ChatDetail/SendAttachmentMessageUseCaseTests.swift` (if not done in M4)

**Files to modify:**
- `AgentChatTests/Features/ChatDetail/ChatDetailViewModelTests.swift`
- `AgentChatTests/Features/ChatList/ChatListViewModelTests.swift`

**What to do:**

1. **ChatListViewModelTests** — add:
   - `testLoadChatsToggleIsLoading`: verify `isLoading` starts `true`, becomes `false` after `loadChats()`.
   - `testDeleteChatCallsUseCase`: verify chat removed from array and use case invoked.

2. **ChatDetailViewModelTests** — add:
   - `testDraftDebounceSavesAfterDelay`: set `draftText`, assert UserDefaults is NOT set immediately, wait 400ms, assert it IS set.
   - `testSaveDraftImmediately`: call `saveDraftImmediately()`, assert UserDefaults is set without delay.
   - `testSendWithAttachmentAppendsMessage`: set a pending attachment, call `sendWithAttachment()`, verify `messages` contains the new file message.
   - `testScrollConstantsAffectBehavior`: call `updateScrollOffset(100)` (below threshold), assert `isNearBottom == true`; call `updateScrollOffset(200)` (above), assert `isNearBottom == false`.

3. Use the Swift Testing framework (`import Testing`, `@Test`, `#expect()`), `@MainActor struct`, matching existing test style.

**Commit:** `test: add coverage for loading state, draft debounce, attachment send, and scroll behavior`

---

## Summary

| Milestone | Severity | Description | Key Files |
|-----------|----------|-------------|-----------|
| M1 | HIGH | Debounce draft saving | ChatDetailViewModel, ChatDetailView |
| M2 | HIGH | Loading state in ChatList | ChatListViewModel, ChatListView |
| M3 | MEDIUM | DeleteChatUseCase | New use case + ChatListViewModel |
| M4 | MEDIUM | SendAttachmentMessageUseCase | New use case + ChatDetailViewModel |
| M5 | MEDIUM | Replace NotificationCenter + awaitable seed | PersistenceController, AgentChatApp, ChatListView |
| M6 | LOW | Extract magic numbers to constants | ChatDetailViewModel |
| M7 | LOW | Additional test coverage | *Tests files |

**Total: 7 commits, one per milestone.**

Each milestone is independently buildable and testable. Run `xcodebuild test` after each commit to verify no regressions.

**Build command:**
```bash
xcodebuild test \
  -project AgentChat.xcodeproj \
  -scheme AgentChat \
  -destination 'platform=iOS Simulator,id=3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC' \
  -only-testing AgentChatTests \
  -quiet
```

**Not addressed (out of scope):**
- VersionedSchema (#5) — no migration path needed for assignment
- Message sync state (#7) — local-only SwiftData, writes don't fail
- Agent architecture refactor (#2) — current ViewModel-driven approach is appropriate for simulated agent
- Domain/Entity separation (#8) — already clean, feedback agreed to keep current approach
- SDWebImage coverage exclusion (#14) — minor config, not architectural
- Docs + profiling (#15, #16) — out of scope
