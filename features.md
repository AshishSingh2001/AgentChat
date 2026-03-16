# Features

## Chat List

- Displays all chats sorted by most recent activity
- Each row shows the chat title, last message preview, and a smart relative timestamp (e.g. "2 min ago", "Yesterday", "Dec 28")
- **Draft preview** — when a chat has an unsent draft and no sent messages, the row shows `Draft: <text>` instead of the last message
- **Swipe to delete** — swipe left on any chat row to reveal a delete button; the chat and all its messages are removed
- **New chat** — tap the compose button to instantly create a new chat and navigate into it
- Chat list re-fetches automatically when navigating back from a chat detail

## Chat Detail

- Displays messages in a bottom-anchored list (newest at the bottom); uses `rotationEffect(180°)` for correct scroll anchoring without pixel-scaling artifacts
- **Message bubbles** — user messages appear right-aligned in blue; agent messages appear left-aligned in gray
- **Auto-scroll** — new user messages always scroll to the bottom immediately; agent messages scroll to the bottom only if the user is within 150px of the newest message
- **"New message" toast** — a pill-shaped "↓ New message" button slides up from the bottom when an agent reply arrives and the user is scrolled away; tapping it jumps to the newest message and dismisses the toast; the toast auto-dismisses after 3 seconds
- **Pagination** — scrolling toward older messages triggers a page load (15 messages per page) with a 1s debounce; a spinner appears at the top while loading; scroll position is preserved after prepend
- **Empty state** — a "No Messages" prompt with a speech bubble icon is shown when the chat has no messages
- **Editable title** — tap the chat title in the nav bar to open a sheet where the title can be renamed; changes are persisted immediately
- **Auto-title** — the chat title is automatically set from the first 30 characters of the user's first message if the title is still "New Chat"
- **Draft persistence** — unsent text in the input bar is automatically saved (300ms debounce) and restored when re-entering the chat, including across app restarts

## AI Agent

- Replies automatically after the user sends messages; the reply decision is based on the count of consecutive user messages since the agent's last reply
- Triggers at counts that are multiples of 4 or 5 (e.g. 4, 5, 8, 10, 12, 15, 16, 20…)
- Each reply is delayed by 2–3 seconds to simulate a realistic typing delay
- **Debounce** — if the user sends multiple messages rapidly, the previous pending reply is cancelled and a new one is scheduled from the latest message
- **Reply types** — 70% plain text from a pool of realistic responses; 30% image (fetched from picsum.photos with a unique seed)
- After replying, the agent updates the chat's `lastMessage` and `lastMessageTimestamp` so the chat list preview stays current
- The agent always reads the latest chat state before updating to avoid overwriting concurrent title edits

## Image Messages

- **Attachment picker** — tap the paperclip button to choose between Photo Library (PhotosPicker) or Camera (UIImagePickerController)
- **Local storage** — selected images are scaled to a JPEG thumbnail (≤150px, scale 1.0) and saved to `Documents/AgentChat/attachments/` with a UUID filename
- **Image bubbles** — image messages display the thumbnail inline in the bubble; tap to open the full-resolution viewer
- **Remote images** — agent image replies use remote URLs (picsum.photos); these are loaded and cached by SDWebImageSwiftUI
- **Error state** — failed image loads (local or remote) show a broken-image icon with "Image unavailable" caption
- **File size** — image bubbles show the file size formatted as KB or MB below the image

## Image Viewer

- Opens as a fullscreen cover over the chat detail
- **Pinch to zoom** — `MagnifyGesture` supports smooth zoom in/out
- **Double-tap to reset** — double-tapping the image resets zoom to 1×
- **Swipe to dismiss** — swipe down to close the viewer
- **Close button** — an explicit × button in the top-right corner also dismisses the viewer

## Offline-First

- All data is stored locally in a GRDB SQLite database (`Documents/agentchat.db`)
- The app loads immediately with no network requests on startup
- Seed data (3 chats, 21 messages) is inserted once on first launch
- File attachments are stored in the app's Documents directory — paths are stored relative (filename only) and resolved to absolute URLs at display time, making them portable across reinstalls
- The message stream uses GRDB `ValueObservation` — new messages from the agent are pushed reactively to the UI without polling
