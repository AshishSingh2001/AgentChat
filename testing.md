# Testing

**92% code coverage** across 94 unit tests and 13 UI tests, using the Swift Testing framework for unit tests and XCTest for UI tests.

Run all tests with `Cmd+U` in Xcode, or via:

```bash
xcodebuild test -project AgentChat.xcodeproj -scheme AgentChat \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro"
```

---

## Unit Tests

All unit tests use in-memory state (no real database, no real filesystem). Mocks live in `AgentChatTests/Mocks/`.

### Domain — `ChatTests`, `DomainErrorsTests`

- Chat and Message structs are value types; equality is structural (all fields)
- `FileAttachment.formattedFileSize` formats bytes correctly at KB and MB boundaries
- Domain error types are defined and typed correctly

### Data — `ChatRepositoryTests`, `MessageRepositoryTests`

- `GRDBChatRepository` and `GRDBMessageRepository` are tested against an in-memory GRDB database
- **Chat CRUD**: insert, fetch by id, fetch all sorted by `lastMessageTimestamp` descending, update, delete
- **Message fetch**: `before: nil` returns latest page in ascending timestamp order; `before: cursor` returns the correct older page
- **Message stream**: `newMessageStream` emits only messages inserted after the observer was attached — existing messages at subscription time are not re-emitted
- **Pagination**: correct page boundary behaviour, empty page when no older messages exist
- **Cascade**: deleting a chat does not delete its messages (messages are cleaned up separately)

### Use Cases

#### `CreateChatUseCaseTests`
- Created chat has a non-empty UUID id
- Title defaults to "New Chat"
- `createdAt` and `updatedAt` are set to the current time
- `lastMessage` is empty string on creation

#### `SendMessageUseCaseTests`
- Sent message is inserted into the repository with correct `chatId`, `text`, `sender`, and `type`
- `lastMessage` and `lastMessageTimestamp` on the chat are updated after send
- **Auto-title**: first message in a chat sets the title to the first 30 characters of the message text; subsequent messages do not change the title
- File attachment messages are inserted with the correct `type: .file` and non-nil `file`
- Throws on repository failure

#### `SimulateAgentReplyUseCaseTests`
- Returns `shouldReply: false` for count = 0
- Returns `shouldReply: false` for non-trigger counts: 1, 2, 3, 6, 7, 9
- Returns `shouldReply: true` at count = 4 (multiple of 4)
- Returns `shouldReply: true` at count = 5 (multiple of 5)
- Image reply is produced when RNG selects image path
- Text reply is produced when RNG selects text path
- Reply text is drawn from the known pool of canned responses

### ViewModels

#### `ChatListViewModelTests`
- Chat list loads from repository on `loadChats()`
- Creating a chat adds it to the list and triggers navigation to the new chat
- Deleting a chat removes it from the list; repository `delete` is called with correct id
- Reactive stream: inserting a chat into the mock repository causes it to appear in `chats` without calling `loadChats()` again

#### `ChatDetailViewModelTests`
- `loadMessages()` fetches the initial page and subscribes to the stream
- Sending a message calls `SendMessageUseCase` and appends the message to the list
- Sending a message calls `agentService.handleUserMessage`
- **Auto-scroll on send**: `scroll.shouldScrollToBottom` is set to `true` after every user message regardless of scroll position
- **Agent reply near bottom**: when `isNearBottom = true`, an agent message sets `shouldScrollToBottom = true`
- **Agent reply far from bottom**: when `isNearBottom = false`, an agent message sets `showNewMessageToast = true` instead
- **Toast auto-dismiss**: toast disappears after 3 seconds without interaction
- **Draft save**: typing in the input triggers a debounced save to the repository
- **Draft restore**: `loadMessages()` restores the saved draft into the input field
- **Pagination**: `loadOlderMessages()` prepends the older page; called again after a 1s debounce; does not fire when `hasMoreMessages = false`
- **Pagination debounce**: rapid calls to `loadOlderMessages()` coalesce into a single repository fetch
- **Rapid send**: each message calls `agentService.handleUserMessage` independently (internal cancellation is the agent's responsibility)
- **Cleanup**: `cleanUpIfEmpty()` deletes the chat only when both `messages` and `draft` are empty
- **Title auto-update**: first message updates `title.chat` to the auto-generated title
- **Title commit**: `commitTitleEdit` persists the new title to the repository

### Services — `AgentServiceTests`

- **Inserts agent message** when `userMessagesSinceLastReply > 0` and decider returns `shouldReply: true`
- **Skips insert** when the message repository is empty (gap = 0)
- **Skips insert** when the last message is already from the agent (gap = 0)
- **Updates chat** after a successful reply — `lastMessage` and `lastMessageTimestamp` are written
- **Uses latest chat title** — fetches fresh chat from repository before updating, avoiding stale title from the captured snapshot
- **Text reply** produces a `.text` message with the correct content string
- **Image reply** produces a `.file` message with a non-nil `FileAttachment` and the correct URL path

### Utilities — `TimestampFormatterTests`

- Timestamps within the last 60 seconds → "Just now"
- Timestamps 1–59 minutes ago → "X min ago"
- Timestamps 1–23 hours ago → "X hours ago"
- Today (earlier) → time string in "h:mm a" format (guards against edge cases within 2 hours of midnight)
- Yesterday → "Yesterday"
- This year (not today/yesterday) → "MMM d" (e.g. "Dec 28")
- Older than this year → "MMM d, yyyy" (e.g. "Dec 28, 2023")

### Data — `FileStorageServiceTests`

- `save(imageData:)` writes to `Documents/AgentChat/attachments/` and returns a relative path (filename only)
- `absoluteURL(for:)` resolves the relative path correctly against the Documents directory
- Round-trip: saved data can be read back from the resolved absolute URL
- Thumbnail generation produces a JPEG at scale 1.0, bounded to 150px on the longest side

---

## UI Tests (XCUITest)

UI tests reset the database to a known seed state before each test using the `--uitesting-reset` launch argument. `continueAfterFailure = false` stops each test at the first failure.

### Chat List
- **Seed data on launch** — all 3 seed chats appear within 15s of launch
- **Create and navigate** — tapping the compose button creates a new chat and shows the "No Messages" empty state
- **Send message** — typing and sending a message makes it appear in the chat; "No Messages" disappears
- **Navigate back shows last message** — after sending, going back shows the sent text as the chat row's last message preview
- **Delete chat** — swipe-left → Delete removes the chat from the list

### Chat Detail
- **Tap seed chat shows messages** — opening "Mumbai Flight Booking" displays the first seed message
- **Auto-title on first message** — a new chat's title updates from "New Chat" to the first 30 characters of the first sent message
- **Send button disabled when empty** — the send button is disabled until text is entered
- **Send button enabled after typing** — typing any text enables the send button
- **Send clears input** — the input field is empty immediately after sending
- **Placeholder visible when empty** — "Message" placeholder is shown when the input is empty
- **Attachment button shows source menu** — tapping the paperclip reveals "Photo Library" and "Camera" options

### Title Edit
- **Sheet appears on title tap** — tapping the nav bar title button opens a sheet with "Rename Chat"
- **Save updates title** — clearing the title field, typing a new title, and tapping Save updates the nav bar
- **Cancel does not change title** — typing in the sheet then tapping Cancel leaves the original title intact

### Image Viewer
- **Tap image opens viewer** — tapping `msg-007` (the seed image in Mumbai Flight Booking) opens the fullscreen viewer with a close button
- **Close button dismisses viewer** — tapping the × button dismisses the viewer

### Agent Reply Behaviour
- **Agent reply updates chat list** — after sending 4 messages to Hotel Reservation Help (gap reaches 4), the agent replies and its text appears as the chat row's last message preview (not the user's last message)
- **Agent reply near bottom auto-scrolls** — staying at the bottom while the agent replies does not show the toast; the view scrolls to the new message automatically
- **Agent reply shows toast when scrolled away** — after sending 4 messages (using `--uitesting-slow-agent` for a 6–8s reply delay), scrolling toward older messages before the reply arrives causes the "New message" toast to appear
- **Tapping toast dismisses it** — tapping the "New message" pill scrolls to the bottom and the toast disappears

### Draft
- **Draft persists across navigation** — typing without sending, going back, and re-entering the chat restores the draft text in the input field; the chat row shows `Draft: <text>`
- **Draft persists after app relaunch** — same as above but the app is fully terminated and relaunched; the draft row and input value survive
