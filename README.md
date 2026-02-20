# terminal-notifier-next

Send macOS User Notifications from the command line. Built for AI coding tools, CI pipelines, and shell scripts.

Requires macOS 10.15+. Packaged as a `.app` bundle because the notification API requires one.

## Installation

```bash
# Build the app bundle
./scripts/build-bundle.sh

# Move to Applications
mv terminal-notifier-next.app /Applications/

# Symlink the binary onto your PATH
sudo ln -sf \
  /Applications/terminal-notifier-next.app/Contents/MacOS/terminal-notifier-next \
  /usr/local/bin/terminal-notifier-next

# On Apple Silicon Macs using Homebrew's prefix:
# sudo ln -sf ... /opt/homebrew/bin/terminal-notifier-next

# Verify
terminal-notifier-next --version
```

On first run, macOS will prompt for notification permission. Grant it in System Settings → Notifications → Terminal Notifier Next.

To make notifications stay until dismissed: System Settings → Notifications → Terminal Notifier Next → Alert style → Alerts.

## Usage

```
terminal-notifier-next --message <text> [options]
terminal-notifier-next --remove <groupID|ALL>
terminal-notifier-next --list <groupID|ALL>
echo "msg" | terminal-notifier-next [options]
```

### Options

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

### Exit codes

- `0` — success
- `1` — error (missing args, permission denied, delivery failed)

## Examples

```bash
# Basic notification
terminal-notifier-next --message "Build done" --title "CI" --sound default

# Pipe output directly
make build 2>&1 | tail -1 | terminal-notifier-next --title "Make"

# Group notifications so only the latest shows
terminal-notifier-next --group myapp --message "Step 1 complete"
terminal-notifier-next --group myapp --message "Step 2 complete"  # replaces step 1

# Flash the terminal window when a long job finishes
sleep 60 && terminal-notifier-next --message "Done" --terminal-alert

# List and remove notifications
terminal-notifier-next --list ALL
terminal-notifier-next --remove ALL
```

## Building from source

Requires Xcode Command Line Tools.

```bash
git clone https://github.com/cspenn/terminal-notifier-next
cd terminal-notifier-next

# Build and bundle (release)
./scripts/build-bundle.sh

# Or build the binary directly
swift build -c release
```

The release binary is ~160KB with no external dependencies.

## License

MIT. See [LICENSE.md](LICENSE.md).

Copyright © 2012–2026 terminal-notifier contributors.

`Terminal.icns` is a custom icon generated from `icon-source.svg`.
