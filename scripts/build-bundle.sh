#!/usr/bin/env bash
# build-bundle.sh
# Builds terminal-notifier.app from the SPM-compiled binary.
# Usage: ./scripts/build-bundle.sh [--configuration release|debug]
#
# Output: terminal-notifier.app in the project root (or $OUTPUT_DIR if set)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIGURATION="${CONFIGURATION:-release}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_ROOT}"

# ─── Build ──────────────────────────────────────────────────────────────────

echo "▶ Building Swift package ($CONFIGURATION)..."
cd "$PROJECT_ROOT"
swift build -c "$CONFIGURATION"

BINARY_PATH="$PROJECT_ROOT/.build/$CONFIGURATION/terminal-notifier-next"
if [ ! -f "$BINARY_PATH" ]; then
    echo "✗ Binary not found at $BINARY_PATH"
    exit 1
fi

# ─── Bundle structure ────────────────────────────────────────────────────────

APP_BUNDLE="$OUTPUT_DIR/terminal-notifier-next.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

echo "▶ Creating .app bundle at $APP_BUNDLE..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$BINARY_PATH" "$MACOS_DIR/terminal-notifier-next"
chmod +x "$MACOS_DIR/terminal-notifier-next"

# Copy Info.plist
cp "$PROJECT_ROOT/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Copy icon (if present)
ICNS="$PROJECT_ROOT/Terminal.icns"
if [ -f "$ICNS" ]; then
    cp "$ICNS" "$RESOURCES_DIR/Terminal.icns"
fi

# ─── Code signing ────────────────────────────────────────────────────────────
# Ad-hoc sign so Gatekeeper accepts the app without a Developer ID.
# For distribution, replace '-' with your Developer ID Application certificate.

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ENTITLEMENTS="$PROJECT_ROOT/Resources/TerminalNotifier.entitlements"

echo "▶ Signing with identity: $SIGN_IDENTITY"
if [ -f "$ENTITLEMENTS" ] && [ "$SIGN_IDENTITY" != "-" ]; then
    codesign --force --options runtime \
             --entitlements "$ENTITLEMENTS" \
             --sign "$SIGN_IDENTITY" \
             "$APP_BUNDLE"
else
    codesign --force \
             --sign "$SIGN_IDENTITY" \
             "$APP_BUNDLE"
fi

echo "✓ Built: $APP_BUNDLE"
echo ""
echo "Test with:"
echo "  $APP_BUNDLE/Contents/MacOS/terminal-notifier-next --message 'Hello' --title 'Test'"
