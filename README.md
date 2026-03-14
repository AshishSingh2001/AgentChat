# AgentChat

An offline-first multi-chat iOS app where users converse with a simulated AI agent. Built with SwiftUI + SwiftData.

---

## Setup

1. Clone the repo
2. Open `AgentChat.xcodeproj` in Xcode 26+
3. Select the `AgentChat` scheme and any iPhone simulator (iOS 26.2+)
4. Run — seed data loads automatically on first launch

No external setup required. SDWebImageSwiftUI is fetched automatically via Swift Package Manager.

---

## Architecture

**Clean Architecture + MVVM**, with feature-first folder organisation.

```
Presentation (Views + ViewModels)    @MainActor
       ↓ depends on
Domain (UseCases + Models + Protocols)    pure Swift
       ↓ depends on
Data (SwiftData Entities + Repositories)  @ModelActor
```

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
- Domain structs: fully immutable (`let` properties), `Sendable` — cross the actor boundary safely

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

- **Chat list** — sorted by last message timestamp, smart relative timestamps, swipe-to-delete, draft preview
- **Chat detail** — message bubbles (user right/blue, agent left/gray), auto-scroll with 150px threshold, "New message" toast
- **AI agent** — replies after every user message (1-2s delay); randomly text or image; debounced on rapid sends
- **Image messages** — send from gallery or camera with preview; stored locally in Documents; fullscreen viewer with pinch-to-zoom and swipe-to-dismiss
- **Offline-first** — all data local via SwiftData; loads instantly with no loading states
- **Empty states** — chat list and chat detail show helpful prompts when empty
- **Error states** — failed image loads show a broken-image icon with "Image unavailable" caption
- **Bonus** — editable chat title (tap nav bar), draft persistence per chat

---

## Testing

Swift Testing framework. Run with Cmd+U in Xcode. Tests cover:

- Domain model invariants (`Chat`, `Message`, `FileAttachment`)
- `@ModelActor` repositories via in-memory `ModelContainer`
- All 3 use cases with injected mock repositories
- `ChatListViewModel` and `ChatDetailViewModel` with mock use cases + mock router
- `TimestampFormatter` (both relative and absolute formats)
- `FileStorageService` with injected temp directory

Nothing in unit tests touches the real SwiftData store or filesystem.

---

## Assumptions

- Agent always replies to user messages — cancelled and re-scheduled on rapid sends (<1.5s)
- Chat title: auto-set from first 30 chars of user's first message; editable at any time
- File paths stored relative (filename only), resolved to absolute on display — portable across reinstalls
- Chats 2 & 3 in seed data have generated messages so they are not empty on first open
- Image viewer presented modally (fullScreenCover), matching platform convention
- Scroll threshold of 150px from bottom for auto-scroll vs toast notification

---

## Build

```bash
# Simulator build
xcodebuild -project AgentChat.xcodeproj -scheme AgentChat \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" build

# Run tests
xcodebuild -project AgentChat.xcodeproj -scheme AgentChat \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" test
```

> **Note:** Archive/IPA requires a signing identity. This project is configured for simulator builds.
