# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

terminal-notifier-next is a macOS command-line tool to send User Notifications. It is a pure Swift rewrite (v3) of the original terminal-notifier. It is packaged as a macOS `.app` bundle because `UNUserNotificationCenter` requires one.

The project uses Swift Package Manager (SPM) with no external dependencies. The release binary is ~160KB.

## Build Commands

```bash
# Development build
swift build

# Release build
swift build -c release

# Build and package as .app bundle (includes code signing)
./scripts/build-bundle.sh

# Test the built app
./terminal-notifier-next.app/Contents/MacOS/terminal-notifier-next --message "Hello" --title "Test"
```

The build script (`scripts/build-bundle.sh`) runs `swift build -c release`, creates the `.app` bundle structure, copies `Resources/Info.plist` and `Terminal.icns`, and ad-hoc signs the bundle. Set `SIGN_IDENTITY` to use a real certificate.

## Architecture

Three Swift source files in `Sources/TerminalNotifierApp/`:

- **`main.swift`** — Entry point. Creates `NSApplication` and `AppDelegate`, then calls `app.run()`. Uses `main.swift` (not `@main`) so the delegate can be set before the run loop starts.

- **`AppDelegate.swift`** — `NSApplicationDelegate` + `UNUserNotificationCenterDelegate`. Hides the app from the Dock (`.accessory` activation policy), registers itself as the notification center delegate, and launches `MainFlow.run()` in a `Task`.

- **`Notifier.swift`** — All business logic (482 lines), containing:
  - **`NotificationSpec`** / **`DeliveredItem`** — Sendable model structs
  - **`NotifierError`** — Error enum with `LocalizedError` conformance
  - **`Notifier` actor** — Core notification engine using `UNUserNotificationCenter`. Handles authorization, delivery (with group deduplication), removal, and listing.
  - **`TerminalEmulator`** — Detects iTerm2, Warp, Kitty, WezTerm from environment variables
  - **`TerminalAlert`** — Flashes the terminal window using emulator-specific escape sequences (OSC-6 for iTerm2, OSC-9 for Warp/WezTerm, OSC-99 for Kitty, ANSI reverse video fallback)
  - **`NotifierArgs`** — Manual CLI argument parser (no external arg-parsing dependency)
  - **`MainFlow`** — Async entry point that reads stdin (piped input), parses args, and dispatches to deliver/remove/list

## CLI Flags

| Flag | Description |
|------|-------------|
| `--message <text>` | Notification body (required unless piped, `--remove`, or `--list`) |
| `--title <text>` | Title (default: Terminal) |
| `--subtitle <text>` | Subtitle |
| `--sound <name>` | Sound name (e.g. `Glass`) or `default`. See `/System/Library/Sounds`. |
| `--group <id>` | Notifications with the same ID replace each other |
| `--remove <id\|ALL>` | Remove delivered notification(s) |
| `--list <id\|ALL>` | List delivered notifications as JSON |
| `--terminal-alert` | Flash the calling terminal window |
| `--terminal-alert-color <c>` | Color: `red` `green` `blue` `yellow` `orange` `purple` `cyan` (default: `red`) |
| `--version` | Print version |
| `--help`, `-h` | Show help |

## Key Behaviors

- **Three modes**: Deliver (default), Remove (`--remove`), List (`--list`)
- **Notification delivery**: The Notifier actor schedules via `UNTimeIntervalNotificationTrigger` with a 0.1s delay, then sleeps 900ms to allow delivery before exiting
- **Piped input**: If stdin is not a TTY and no `--message`/`--remove`/`--list` is given, stdin is read as the message body using `poll()` with zero timeout to avoid blocking
- **Group IDs**: Notifications with the same group ID replace each other; `ALL` targets all notifications for remove/list
- **Sound names**: Listed in `/System/Library/Sounds`; use `default` for the system default sound
- **Terminal flash**: `--terminal-alert` uses terminal-specific escape sequences to briefly flash the terminal background
- **JSON output**: `--list` outputs formatted JSON with ISO8601 timestamps
- **Exit codes**: 0 for success, 1 for error

## Important Constraints

- macOS 10.15+ required (uses `UNUserNotificationCenter`)
- Swift 5.9+ / Swift Package Manager
- Must be distributed as an `.app` bundle — `UNUserNotificationCenter` requires a running app with a bundle identifier
- Version is read from `Resources/Info.plist` (`CFBundleShortVersionString`), currently 3.0.0
- First run requires granting notification permission interactively
- No external dependencies

## Project Structure

```
Sources/TerminalNotifierApp/   # Swift source (3 files)
Resources/                     # Info.plist, entitlements
scripts/                       # build-bundle.sh
Tests/TerminalNotifierTests/   # Test directory (currently empty)
docs/                          # Documentation
archive/                       # Archived original Obj-C and Ruby code
Package.swift                  # SPM manifest
```

# currentDate
Today's date is 2026-02-20.
