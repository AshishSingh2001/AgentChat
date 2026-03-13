# AgentChat

An offline-first multi-chat iOS app where users converse with a simulated AI agent. Built with SwiftUI + SwiftData

---

## Setup

1. Clone the repo
2. Open `AgentChat.xcodeproj` in Xcode
3. Select the `AgentChat` scheme and any iPhone simulator (iOS 17+)
4. Run — seed data loads automatically on first launch

No external setup required. SDWebImageSwiftUI is fetched automatically via Swift Package Manager.

---

## Architecture

**Clean Architecture + MVVM**, with feature-first folder organisation.

| Presentation | Domain | Data |
|---|---|---|
| Views + ViewModels | UseCases + Models + Protocols | SwiftData Entities + Repos |

### Layers

| Layer | Contents | Rule |
|---|---|---|
| `Domain/` | `Chat`, `Message` structs; repository protocols | Pure Swift — zero UIKit/SwiftData imports |
| `Data/` | `@Model` entities; `@ModelActor` repositories; seed loader | Implements domain protocols |
| `Features/*/UseCases/` | Business logic only | Stateless — no Tasks, no timers |
| `Features/*/` | Views + `@Observable @MainActor` ViewModels | Owns UI state + async Task lifecycle |
| `Navigation/` | `AppRoute` enum + `AppRouter` | All navigation through one router |

### Concurrency

- Repositories: `@ModelActor` — safe SwiftData access, returns `Sendable` domain structs
- ViewModels: `@MainActor` — drives SwiftUI state
- Domain structs: `Sendable` — cross the actor boundary safely

### Navigation

`NavigationPath` + typed `AppRoute` enum. A single `AppRouter` (@Observable) is injected via `.environment`. ViewModels push routes; views never navigate directly. Image viewer is `.fullScreenCover` (modal), not a stack push.

### Use Cases

| Use Case | Logic |
|---|---|
| `CreateChatUseCase` | Generates UUID, sets timestamps and placeholder title |
| `SendMessageUseCase` | Inserts message + updates chat metadata + auto-titles on first message |
| `SimulateAgentReplyUseCase` | Pure: given message count + injectable RNG → should reply? what type? |

Simple CRUD reads/deletes go directly from ViewModel to repository.

---

## Features

- **Chat list** — sorted by last message timestamp, smart relative timestamps, swipe-to-delete with confirmation
- **Chat detail** — message bubbles (user right/blue, agent left/gray), auto-scroll with 150px threshold, "↓ New message" toast
- **AI agent** — replies every 4-5 messages after 1-2s delay; 70% text, 30% image; debounced on rapid sends
- **Image messages** — send from gallery or camera; stored locally in Documents; fullscreen viewer with pinch-to-zoom
- **Offline-first** — all data local via SwiftData; loads instantly with no loading states
- **Bonus** — editable chat title, draft persistence per chat, empty states

---

## Testing

Swift Testing framework. Tests cover:

- Domain model invariants (`Chat`, `Message`, `FileAttachment`)
- `@ModelActor` repositories via in-memory `ModelContainer`
- All 3 use cases with injected mock repositories
- `ChatListViewModel` and `ChatDetailViewModel` with mock use cases + mock router
- `TimestampFormatter` (both relative and absolute formats)
- `FileStorageService` with injected temp directory

Nothing in unit tests touches the real SwiftData store or filesystem.

---

## Assumptions

- Agent reply trigger: counter resets on rapid sends (<1.5s apart) — prevents reply spam
- Chat title: auto-set from first 30 chars of user's first message; editable at any time after
- File paths stored relative (filename only), resolved to absolute on display — survives reinstall
- Chats 2 & 3 in seed data have generated messages so they are not empty on first open
- Image viewer presented modally (fullScreenCover), matching platform convention (iMessage, WhatsApp)
