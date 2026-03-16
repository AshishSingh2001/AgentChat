# AgentChat

Demo : https://drive.google.com/file/d/1ZkLbh__vmUaebd4SXWk4rpxvpzA5kGIU/view?usp=drive_link

AgentChat is an offline-first multi-chat iOS app where users have conversations with a simulated AI agent. Every message, image, and chat is persisted locally — there is no network dependency, no sign-in, and no loading states. The app launches straight into your chats.

The agent replies automatically after a short delay, occasionally responding with images. It debounces on rapid sends, counts the gap since its last reply to decide when to respond, and updates the chat list preview in real time. The UI is built entirely in SwiftUI with Clean Architecture + MVVM, GRDB for persistence, and reactive streams as the sole source of truth for the message list.

---

## Setup

1. Clone the repo
2. Open `AgentChat.xcodeproj` in Xcode 26+
3. Select the `AgentChat` scheme and any iPhone simulator (iOS 26.2+)
4. Run — seed data loads automatically on first launch

No external setup required. SDWebImageSwiftUI and GRDB are fetched automatically via Swift Package Manager.

---

## Architecture

**Clean Architecture + MVVM**, with feature-first folder organisation.

```
Presentation (Views + ViewModels)      @MainActor
       ↓ depends on
Domain (UseCases + Models + Protocols) pure Swift
       ↓ depends on
Data (GRDB Entities + Repositories)    thread-safe, Sendable
```

### Layers

| Layer | Contents | Rule |
|---|---|---|
| `Domain/` | `Chat`, `Message` structs; repository protocols | Pure Swift — zero UIKit/GRDB imports |
| `Data/` | GRDB records; repositories; seed loader | Implements domain protocols |
| `Features/*/UseCases/` | Business logic only | Stateless — no Tasks, no timers |
| `Features/*/` | Views + `@Observable @MainActor` ViewModels | Owns UI state + async Task lifecycle |
| `Services/` | `AgentService` (actor), `FileStorageService` | Cross-cutting, injected at root |
| `Navigation/` | `AppRoute` enum + `AppRouter` | All navigation through one router |

### Concurrency

- Repositories: `final class @unchecked Sendable` backed by GRDB `DatabaseQueue` — safe concurrent access, returns `Sendable` domain structs
- ViewModels: `@MainActor` — drives SwiftUI state
- `AgentService`: Swift `actor` — thread-safe, debounces internally, fire-and-forget entry point
- Domain structs: fully immutable (`let` properties), `Sendable` — cross actor boundaries safely

### Navigation

`NavigationPath` + typed `AppRoute` enum. A single `AppRouter` (`@Observable`) is injected via `.environment`. ViewModels push routes; views never navigate directly. Image viewer uses `.fullScreenCover` (modal).

### Use Cases

| Use Case | Logic |
|---|---|
| `CreateChatUseCase` | Generates UUID, sets timestamps and placeholder title |
| `SendMessageUseCase` | Inserts message + updates chat metadata + auto-titles on first message |
| `SimulateAgentReplyUseCase` | Pure: given user message gap + injectable RNG → should reply? what type? |

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
