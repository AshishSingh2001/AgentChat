# Plan Review — Opus Feedback

Reviewer context: SDE-2 iOS interview submission, 3-4 day timeline, SwiftUI + SwiftData.

---

## What's Strong

1. **Layer separation is clean.** Domain models as plain structs, SwiftData entities only in `Data/`, mapping between them — textbook Clean Architecture. Reviewers will see intentional design.

2. **Testability story is solid.** Protocol-based repositories, injectable use cases, mock-friendly ViewModels. Demonstrating you can test business logic without a database is the right SDE-2 signal.

3. **Feature-first folders** — easy to navigate, scales naturally. Good choice over layer-first.

4. **TDD sequencing is correct.** Domain → Data → Services → Navigation → Features is the right bottom-up order.

5. **Navigation design is good.** Enum-based routes with `NavigationPath` and a central router via environment injection. Deep-linkable, testable, clean.

---

## Issues

### HIGH — Must Fix

#### H1. No `@Sendable` / `@ModelActor` strategy

The project targets iOS 26.2 with Swift 6 concurrency (pbxproj shows approachable concurrency, MainActor by default). This means:

- ViewModels will be `@MainActor` by default.
- Repository protocols need `@Sendable` consideration if accessed from background contexts.
- SwiftData `ModelContext` is **not** `Sendable` — you cannot pass it between actors.

The plan doesn't address this. In practice, you'll hit `Sendable` errors the moment a `@MainActor` ViewModel calls a repository method inside a `Task`.

**Fix:** Concrete repositories should use `@ModelActor` (SwiftData's built-in actor isolation). ViewModels are `@MainActor`. Use cases bridge the gap — their `async` methods cross the actor boundary. Document this in the plan and write it into the repository implementation steps.

---

### MEDIUM — Should Fix

#### M1. Too many pass-through use cases

`FetchChatsUseCase` is literally:
```swift
func execute() async throws -> [Chat] {
    try await chatRepository.fetchAll()
}
```

That's a file, a protocol, a mock, and a test for zero business logic. Same for `FetchMessagesUseCase`, `DeleteChatUseCase`, `UpdateChatTitleUseCase`.

For a 3-day assignment, reviewers will see extra layers as ceremony, not sophistication. An SDE-2 should show judgement about when abstraction earns its keep.

**Fix:** Only create use cases where there's orchestration or multi-step business logic:
- `SendMessageUseCase` — **keep** (inserts message + updates chat metadata + triggers auto-title on first message)
- `SimulateAgentReplyUseCase` — **keep** (random logic, delay, type decision)
- `CreateChatUseCase` — **keep** (generates defaults, returns new Chat)
- `FetchChatsUseCase` — **drop**, ViewModel calls repository directly
- `FetchMessagesUseCase` — **drop**, ViewModel calls repository directly
- `DeleteChatUseCase` — **drop**, ViewModel calls repository directly (one-liner)
- `UpdateChatTitleUseCase` — **drop**, fold into ViewModel or `SendMessageUseCase`'s auto-title path

#### M2. Debounce logic in a UseCase is architecturally wrong

`SimulateAgentReplyUseCase` is described as owning the debounce timer and `Task` cancellation. But use cases should be stateless — call in, get result out. A long-lived debounce timer with `Task` cancellation is ViewModel-level state management.

**Fix:** Split the responsibilities:
- **UseCase (stateless, pure):** "Given `userMessageCount` and a random seed, should I reply? If yes, what type and content?" — a pure function, trivially testable.
- **ViewModel (stateful):** Owns the debounce `Task`, cancels on rapid send, calls the use case after the delay elapses. This is where `Task.sleep` and cancellation live.

#### M3. DI wiring comes too late (Phase 9)

All features are built in isolation through Phases 6-8 but only wired together in Phase 9. This means you can't build-install-launch until Phase 9. Integration bugs surface late, and you violate the CLAUDE.md agentic loop (build → install → launch → verify after every change).

**Fix:** Move basic DI wiring to Phase 5 alongside Navigation. Create `AppView` with the `NavigationStack`, wire up `ModelContainer`, create repositories, inject into a minimal ChatListView. From Phase 6 onward, every feature addition should be immediately runnable on the simulator.

#### M4. ChatList ↔ ChatDetail data sync strategy is undefined

When the user sends a message in ChatDetail, ChatList's `lastMessage` and `lastMessageTimestamp` must update. The plan says `SendMessageUseCase` updates the chat entity, but never explains how `ChatListViewModel` learns about the change.

**Fix:** Define the strategy explicitly. Options:
- **Option A (simplest):** `ChatListView` uses `.task(id: router.path.count)` or `.onAppear` to re-fetch chats whenever the view appears. Works because navigating back triggers `onAppear`.
- **Option B (reactive):** Use SwiftData observation — if the view layer uses `@Query` for the chat list directly, SwiftData handles reactivity automatically. This is a pragmatic shortcut: skip the ViewModel for the read path on chat list, use ViewModel only for mutations.
- **Option C:** Shared `@Observable` state object both ViewModels reference.

Pick one and document it. An interviewer will ask "what happens to the list when you send a message and go back?"

#### M5. Skipped pinch-to-zoom despite it being in the spec

The assignment explicitly states: *"Click image to open fullscreen with pinch-to-zoom."* The plan chose "Simple fullscreen only — no zoom." For an SDE-2 submission, knowingly skipping an explicit requirement is something a reviewer will flag — even if the complexity seems low priority.

**Fix:** Add basic pinch-to-zoom. It's ~10 lines:
```swift
@State private var scale: CGFloat = 1.0

image
    .scaleEffect(scale)
    .gesture(MagnifyGesture().onChanged { scale = $0.magnification })
```
Trivial effort, closes a requirements gap.

#### M6. `TimestampFormatter` conflates two different formatting jobs

Chat list needs **relative** formatting ("2m ago", "Yesterday"). Message bubbles need **absolute** time ("2:30 PM"). The plan mentions one `TimestampFormatter` without distinguishing these.

**Fix:** Make both explicit in the plan:
- `TimestampFormatter.relativeString(from:)` → for chat list rows
- `TimestampFormatter.timeString(from:)` → for message bubble timestamps

Both live in the same file. Minor, but the tests should cover both paths.

---

### LOW — Nice to Fix

#### L1. No `Mocks/` folder in test structure

12+ test files all need `MockChatRepository`, `MockMessageRepository`, `MockAppRouter`, mock use cases. These are shared across test files. The plan doesn't say where they live.

**Fix:** Add `AgentChatTests/Mocks/` with:
- `MockChatRepository.swift`
- `MockMessageRepository.swift`
- `MockAppRouter.swift`
- `MockFileStorageService.swift`

#### L2. Seed data for Chats 2 and 3 has no messages

The assignment only provides 10 messages for Chat 1. Chats 2 and 3 have `lastMessage` text but no actual message records. A reviewer will tap into them and see either empty chats or a `lastMessage` preview that doesn't correspond to any real message — both look like bugs.

**Fix:** Generate 5-8 messages each for Chats 2 and 3 during seed loading. Doesn't need to be spec'd in detail — just note it in Phase 3.

#### L3. Missing `README.md` in the plan

The assignment deliverables explicitly require:
> `README.md` with setup instructions, brief explanation of architecture decisions, any assumptions made.

The plan's commit cadence and milestones don't include it.

**Fix:** Add README creation as a step in Phase 10 (or its own final phase). Include: architecture diagram, setup steps, assumptions, and a note on the TDD approach.

#### L4. `.imageViewer` route pushes onto NavigationStack — should it?

The plan has `.imageViewer(imageURL:localPath:)` as a `NavigationPath` push. But image viewers are typically presented modally (`.fullScreenCover` or `.sheet`) — they're an overlay, not a navigation destination. Pushing means the user sees a back chevron and nav bar, which is non-standard for image viewers.

**Fix:** Present `ImageViewerView` via `.fullScreenCover` triggered by state in `ChatDetailViewModel`, not via `AppRouter.push`. Remove `.imageViewer` from `AppRoute`. This is how every major iOS app (iMessage, WhatsApp, Telegram) does it.

---

## Revised Use Case Inventory

After applying M1 and M2:

| Use Case | Keep? | Reason |
|---|---|---|
| `FetchChatsUseCase` | Drop | Pass-through, ViewModel calls repo directly |
| `CreateChatUseCase` | Keep | Generates UUID, sets defaults, returns Chat |
| `DeleteChatUseCase` | Drop | One-liner delete, no orchestration |
| `FetchMessagesUseCase` | Drop | Pass-through |
| `SendMessageUseCase` | Keep | Multi-step: insert message + update chat metadata + auto-title on first message |
| `UpdateChatTitleUseCase` | Drop | Fold into SendMessageUseCase (auto) or ViewModel (manual edit) |
| `SimulateAgentReplyUseCase` | Keep (stateless) | Pure decision: should reply? what type? ViewModel owns the timer |

3 use cases instead of 7. Each one earns its existence.

---

## Revised Test Inventory

```
AgentChatTests/
├── Mocks/
│   ├── MockChatRepository.swift
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

Fewer test files, each one testing meaningful logic.

---

## Summary

| ID | Issue | Severity | Status |
|---|---|---|---|
| H1 | No @Sendable / @ModelActor strategy | HIGH | Must add before Phase 3 |
| M1 | Too many pass-through use cases | MEDIUM | Drop 4, keep 3 |
| M2 | Stateful debounce in UseCase | MEDIUM | Move timer to ViewModel |
| M3 | DI wiring too late | MEDIUM | Move to Phase 5 |
| M4 | ChatList ↔ ChatDetail sync undefined | MEDIUM | Pick and document strategy |
| M5 | Skipped pinch-to-zoom | MEDIUM | Add it — trivial, in spec |
| M6 | Two timestamp formats conflated | MEDIUM | Clarify both in plan |
| L1 | No Mocks/ folder | LOW | Add to test structure |
| L2 | Chats 2 & 3 have no seed messages | LOW | Generate them |
| L3 | Missing README deliverable | LOW | Add to Phase 10 |
| L4 | Image viewer should be modal, not push | LOW | Use .fullScreenCover |
