 # CLAUDE.md — AgentChat iOS

Read this file in full at the start of every session before taking any action.

---

## Project Identity

- Project file: `AgentChat.xcodeproj`
- Scheme: `AgentChat`
- Bundle ID: `com.llance.AgentChat`
- Configuration: `Debug`
- DerivedData: `DerivedData/` (relative to project root)
- App binary (simulator): `DerivedData/Build/Products/Debug-iphonesimulator/AgentChat.app`
- Preferred simulator UDID: `3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC`

Always use the explicit UDID. Never use `booted` or name-based references — they are non-deterministic.

When searching or grepping, exclude `DerivedData/` unless you are explicitly looking for build artifacts or Swift Package source.

---

## Control Flags

These flags define what you are permitted to do in this session. Check the relevant flag before performing any action. If a flag is DISABLED, stop and ask the human to enable it before proceeding.

```
BUILD_ENABLED              = true    # xcodebuild
INSTALL_ENABLED            = true    # simctl install
LAUNCH_ENABLED             = true    # simctl launch
CONSOLE_LOGS_ENABLED       = true    # --console-pty output
OSLOG_ENABLED              = true    # spawn log stream
SCREENSHOTS_ENABLED        = true    # simctl io screenshot
SIMULATOR_CONTROL_ENABLED  = false   # axe tap / gesture (DISABLED)
DELETE_ENABLED             = false   # rm / erase commands (DISABLED)
```

The human can toggle any flag mid-session by saying, for example: "enable simulator control" or "disable build". Update your understanding immediately when this happens.

---

## Step 1 — Build

Requires: `BUILD_ENABLED = true`

```bash
xcodebuild \
  -project AgentChat.xcodeproj \
  -scheme AgentChat \
  -destination "platform=iOS Simulator,id=3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC" \
  -derivedDataPath DerivedData \
  -configuration Debug \
  build 2>&1 | xcsift -w
```

`xcsift -w` filters build output to errors and warnings only. Install: `brew install xcsift`.

The `-derivedDataPath DerivedData` flag is mandatory. Without it, xcodebuild writes to a different directory than Xcode, breaking the shared build cache and forcing a clean build every time.

Builds are expected to be incremental. If every build is slow, the cache is broken — report it to the human instead of deleting DerivedData.

Do not run `rm -rf DerivedData` to fix build problems. It causes Xcode to lose Swift Package references and requires a full restart. `DELETE_ENABLED` is off by default for this reason.

---

## Step 2 — Install

Requires: `INSTALL_ENABLED = true`

Run after a successful build. Copies the app binary into the simulator.

```bash
xcrun simctl install \
  3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC \
  "DerivedData/Build/Products/Debug-iphonesimulator/AgentChat.app"
```

---

## Step 3 — Launch

Requires: `LAUNCH_ENABLED = true`

Basic launch (no log capture):

```bash
xcrun simctl launch \
  3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC \
  com.llance.AgentChat
```

IMPORTANT: Always add `--terminate-running-process` when you need log output. Without it, if the app is already running, `launch` silently does nothing and produces no logs. This is the most common cause of empty log output and confused debugging sessions.

---

## Step 4 — Console and Log Output

Choose the appropriate option based on expected output volume and whether you need to drive the simulator simultaneously.

### Option A — Blocking, direct (short flows, output under ~50 lines)

Use for quick verification of a known code path where you want output inline.

Requires: `LAUNCH_ENABLED = true`, `CONSOLE_LOGS_ENABLED = true`

```bash
xcrun simctl launch \
  --console-pty \
  --terminate-running-process \
  3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC \
  com.llance.AgentChat
```

### Option B — Blocking, to file (heavy or unknown output volume)

Requires: `LAUNCH_ENABLED = true`, `CONSOLE_LOGS_ENABLED = true`

```bash
xcrun simctl launch \
  --console-pty \
  --terminate-running-process \
  3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC \
  com.llance.AgentChat > DerivedData/tmp/console.log 2>&1
```

After the session, read and analyze only the relevant portion of `DerivedData/tmp/console.log`.

### Option C — Non-blocking, background (extended sessions or when driving the simulator)

Requires: `LAUNCH_ENABLED = true`, `CONSOLE_LOGS_ENABLED = true`

Use `run_in_background: true` on the Bash tool. This keeps the command alive without blocking the prompt.

```
Bash(
  command: "xcrun simctl launch --console-pty --terminate-running-process 3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC com.llance.AgentChat",
  run_in_background: true
)
# Returns a task_id, e.g. b8e2ca5

# When done:
TaskOutput(task_id: "b8e2ca5")
KillShell(shell_id: "b8e2ca5")
```

### Option D — OSLog / Logger, non-blocking

Requires: `LAUNCH_ENABLED = true`, `OSLOG_ENABLED = true`

`spawn log stream` only captures logs emitted after it starts. Always start it before launching the app.

```
Bash(
  command: "xcrun simctl spawn 3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC log stream --level=debug --predicate 'subsystem == \"com.llance.AgentChat\"'",
  run_in_background: true
)
# Returns task_id, e.g. b8e2ca5

Bash(
  command: "xcrun simctl launch --terminate-running-process 3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC com.llance.AgentChat"
)

# When done:
TaskOutput(task_id: "b8e2ca5")
KillShell(shell_id: "b8e2ca5")
```

---

## Step 5 — Screenshots

Requires: `SCREENSHOTS_ENABLED = true`

Simulator screenshots are 3x resolution. Resize to 1x immediately so that pixel coordinates in the image match logical tap coordinates.

```bash
xcrun simctl io 3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC screenshot DerivedData/tmp/screen.png \
  && magick DerivedData/tmp/screen.png -resize 33.333% DerivedData/tmp/screen_1x.png
```

Read `DerivedData/tmp/screen_1x.png`. Pixel coordinates in this image correspond directly to tap coordinates.

Install ImageMagick: `brew install imagemagick`

### Tap coordinate verification (use before any tap)

Before tapping, verify coordinates by drawing a red box at the target location and reading the marked image:

```bash
magick DerivedData/tmp/screen_1x.png \
  -fill none -stroke red -strokewidth 2 \
  -draw "rectangle $((X-30)),$((Y-30)) $((X+30)),$((Y+30))" \
  DerivedData/tmp/screen_marked.png
```

Read `screen_marked.png`. If the box is not centered on the target element, adjust X/Y and repeat. Only tap once the box confirms correct placement.

---

## Step 6 — Simulator Control (Tap and Gesture)

Requires: `SIMULATOR_CONTROL_ENABLED = true`

This flag is DISABLED by default. Do not attempt tap or gesture commands until the human enables it.

Install AXe: `brew install axe`

```bash
# Tap at 1x logical coordinates
axe tap -x 201 -y 297 --udid 3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC --post-delay 0.5

# Scroll — names refer to finger direction, not content direction
axe gesture scroll-up   --udid 3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC --post-delay 0.5  # finger up = content moves up = reveals content below
axe gesture scroll-down --udid 3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC --post-delay 0.5  # finger down = content moves down = reveals content above

# Back navigation (pop NavigationStack)
axe gesture swipe-from-left-edge --udid 3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC --post-delay 0.5
```

Accessibility description (text-based alternative to screenshots, less reliable on iOS 26+):

```bash
axe describe-ui --udid 3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC
```

Note: `describe-ui` does not reliably report tab bars or toolbars on iOS 26+. Prefer screenshots for navigation decisions.

---

## Agentic Loop

For every coding task, follow this sequence without skipping steps:

1. Write code changes
2. Build — fix all errors and warnings before continuing
3. Install — deploy the new binary to the simulator
4. Launch with `--terminate-running-process` and capture console output
5. Analyze logs — confirm expected behavior or diagnose the problem
6. Screenshot (if the change is visual) — confirm the UI is correct
7. Report findings to the human before moving to the next task

Do not assume a step succeeded without verifying its output.

---

## Hard Rules

Do not use `--stdout` or `--stderr` with `simctl launch`. They do not work. Use `--console-pty`.

Do not launch without `--terminate-running-process` when log output is needed. A silent no-op is the most common cause of missing logs.

Do not delete or erase DerivedData under any circumstances unless `DELETE_ENABLED = true`. Ask the human first.

Do not use simulator names or `booted` as build destinations. Always use the explicit UDID.

Do not perform any action whose corresponding flag is DISABLED. Stop and ask the human.

---

## Simulator Utilities

```bash
# List all available simulators
xcrun simctl list devices available

# Find latest iPhone Pro UDID
xcrun simctl list devices available | grep "iPhone.*Pro (" | tail -1 | grep -Eo '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}'

# Boot simulator
xcrun simctl boot 3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC

# Erase simulator app data (requires DELETE_ENABLED = true)
xcrun simctl erase 3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC

# Add image to simulator Photos
xcrun simctl addmedia 3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC /path/to/image.png

# Open a deep link
xcrun simctl openurl 3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC "agentchat://path?param=value"

# Create log/screenshot output directory (run once per session)
mkdir -p DerivedData/tmp
```

---

## Session Start Checklist

- Confirm the simulator `3CD8C79F-AA1D-4397-B7AC-08B1998F0DAC` is booted, or boot it
- Run `mkdir -p DerivedData/tmp` to ensure the output directory exists
- Confirm current control flags with the human if the session involves risky operations
- Run one build to confirm the incremental cache is warm before starting work