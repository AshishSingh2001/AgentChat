# AgentChat — Technical Overview

## Architecture

**Clean Architecture + MVVM** with strict inward dependency flow:

```
Presentation → Domain ← Data
```

- **Domain layer** — plain Swift structs (`Chat`, `Message`, `FileAttachment`) + protocol interfaces (`ChatRepositoryProtocol`, `MessageRepositoryProtocol`). Zero framework imports. Fully `Sendable`.
- **Data layer** — GRDB SQLite repositories behind those protocols. `ChatRecord`/`MessageRecord` are the only types that know about the database schema. Domain models never touch GRDB.
- **Presentation layer** — `@Observable @MainActor` ViewModels consume use cases and repository protocols via constructor injection. Views are passive; they read state and forward actions.

---

## Key Technical Decisions

**GRDB over SwiftData**
- SQL migrations give full schema control (`v1_initial` with foreign keys, index on `(chatId, timestamp)`)
- `ValueObservation` drives reactive streams — the chat list and message list update automatically when the DB changes, with no manual invalidation
- Partial column updates (`updateTitle`, `updateDraft`) prevent write races between concurrent DB writers (e.g. `AgentService` updating `lastMessage` while `DraftViewModel` saves draft)

**`@Observable` + `@MainActor` ViewModels**
- All ViewModel properties are implicitly tracked — no `@Published`, no `ObservableObject`, no manual `objectWillChange`
- `@MainActor` enforces single-threaded access at compile time; no locks needed
- `ChatDetailViewModel` composes five focused sub-VMs (`MessageListViewModel`, `DraftViewModel`, `TitleViewModel`, `MessageScrollCoordinator`, `ImageViewerViewModel`) — each owns exactly one concern

**`AgentService` as an `actor`**
- Isolated from `@MainActor`; reply logic runs off the main thread with no contention
- `pendingTask?.cancel()` on each new user message prevents a stale reply from an earlier send overtaking a newer one
- `nonisolated func handleUserMessage` is the single entry point callable from `@MainActor` ViewModels

**Reactive streams as sole source of truth**
- `chatStream() → AsyncStream<[Chat]>` feeds `ChatListViewModel` directly — no manual refetch on pop
- `newMessageStream(for:) → AsyncStream<Message>` feeds `MessageListViewModel` — agent-inserted messages appear automatically without polling
- Both streams are backed by GRDB `ValueObservation` on the real database, so they reflect every write regardless of which actor makes it

---

## Concurrency Model

| Component | Isolation | Reason |
|---|---|---|
| All ViewModels | `@MainActor` | UI reads always on main thread |
| `AgentService` | `actor` | Background reply logic, no main-thread blocking |
| Domain structs | `Sendable` | Safe to pass across actor boundaries |
| GRDB repositories | `@unchecked Sendable` | GRDB `DatabaseQueue` handles its own serialization |
| Mocks | `@unchecked Sendable` | Test-only; no real concurrency in tests |

---

## Notable Edge Cases Handled

**Write race between `DraftViewModel` and `AgentService`**
Previously both did fetch→rebuild→write on the whole `Chat` row. If they overlapped, one would clobber the other's field (`lastMessage` vs `draftText`). Fixed by adding `updateTitle(id:title:)` and `updateDraft(id:draftText:)` — targeted SQL `UPDATE` statements touching only their own columns.

**Agent reply decision is deterministic in tests**
`SimulateAgentReplyUseCase` picks an interval from `4...5` using the system RNG. UI tests that send exactly 4 messages would pass ~50% of the time (flaky) because `4 % 5 ≠ 0`. Fixed with a `--uitesting-reply-every-4` launch argument that forces `replyIntervalRange: 4...4`, making the reply guaranteed and deterministic.

**Scroll UX threshold**
`MessageScrollCoordinator` tracks `offsetFromBottom` via `onScrollGeometryChange`. Below 150px → `isNearBottom = true` → new messages auto-scroll. Above 150px → toast pill appears with a 3-second auto-dismiss. User messages always force-scroll regardless of position.

**Pagination without jank**
`MessageListView` renders messages in reverse chronological order using a 180° `rotationEffect` on the `ScrollView` — this makes the visual bottom the natural scroll origin, so the list always opens at the newest message with no programmatic scroll needed on first load.

**Draft debounce**
`DraftViewModel.text.didSet` cancels and re-schedules a 300ms `Task` on every keystroke. `saveImmediately()` is called on view disappear and on send, guaranteeing the draft is written to the DB before navigation or before the input clears.

**`TitleViewModel` double-animation fix**
`ChatDetailViewModel` used to init with `Chat(title: "")`, then update to the real chat in `loadMessages()`. SwiftUI animated the toolbar text change on every load even for existing chats. Fixed by passing the full `Chat` at init, so the title is correct on the first render.

Separately, `MessageListViewModel.load()` setting `messages = page` causes a second `body` invalidation that would re-animate the toolbar even when `displayTitle` hadn't changed. Fixed by extracting the toolbar title into a `ChatTitleButton` subview — its `body` only re-evaluates when `TitleViewModel` properties change, not when the message list updates.

---

## Test Coverage

**94 unit tests** across Domain, Data, Use Cases, ViewModels, Services, and Utilities.

| Area | What's tested |
|---|---|
| `ChatDetailViewModelTests` (41 tests) | Message send/load, pagination, draft save/restore, title edit, agent reply, scroll coordinator, error propagation |
| `SimulateAgentReplyUseCaseTests` | Reply trigger counts (4, 5), image vs text probability, fixed-interval config |
| `ChatRepositoryTests` / `MessageRepositoryTests` | GRDB read/write/delete/stream with real in-memory database |
| `AgentServiceTests` | Task cancellation on rapid send, reply delay, DB writes |
| `TimestampFormatterTests` | Narrow no-break space in AM/PM (U+202F), relative date strings, midnight boundary |
| `SeedDataLoaderTests` | `resetAndReload()` deletes all rows before reseeding; `UserDefaults` flag behaviour |

**8 XCUITests** covering full user journeys with DB isolation via `--uitesting-reset`:
- Seed data visibility, new chat creation, message send, agent reply, auto-title, image viewer, title editing, swipe-delete

Each UI test relaunches the app with `--uitesting-reset` → `SeedDataLoader.resetAndReload()` → clean known state. Tests that depend on the agent replying also pass `--uitesting-reply-every-4` to eliminate RNG flakiness.

---

## Project Structure

```
AgentChat/
├── Domain/          Pure Swift — Chat, Message, protocols, errors
├── Data/            GRDB — AppDatabase, repositories, records, SeedDataLoader
├── Features/
│   ├── ChatList/    ViewModel + Views (reactive stream, create, delete)
│   └── ChatDetail/  5 sub-VMs + UseCases + Views (send, scroll, draft, title, image)
├── Services/        AgentService (actor), FileStorageService
├── Navigation/      AppRoute enum, AppRouter (@Observable)
├── Utilities/       TimestampFormatter, ErrorAlert view modifier
└── App/             PersistenceController, AppView (DI root), AgentChatApp

AgentChatTests/
├── Mocks/           5 mock implementations with stream support
└── [mirrors source structure]

AgentChatUITests/    8 XCUITests with launch argument isolation
```
