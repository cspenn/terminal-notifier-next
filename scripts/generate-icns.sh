#!/usr/bin/env bash
# generate-icns.sh
# Converts icon-source.svg → Terminal.icns via PNG intermediates.
# Requires: rsvg-convert (from librsvg, install via: brew install librsvg)
#
# Usage: ./scripts/generate-icns.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SVG="$PROJECT_ROOT/icon-source.svg"
ICONSET="$PROJECT_ROOT/Terminal.iconset"
ICNS="$PROJECT_ROOT/Terminal.icns"

if [ ! -f "$SVG" ]; then
    echo "✗ SVG not found at $SVG"
    exit 1
fi

# Check for rsvg-convert (handles SVG filters like blur correctly)
if command -v rsvg-convert &>/dev/null; then
    CONVERT_CMD="rsvg"
elif command -v sips &>/dev/null; then
    # sips can convert SVG but may not render filters (glow, blur)
    echo "⚠ Using sips (filters like glow may not render). Install librsvg for best results:"
    echo "  brew install librsvg"
    CONVERT_CMD="sips"
else
    echo "✗ No SVG converter found. Install librsvg: brew install librsvg"
    exit 1
fi

echo "▶ Generating icon set from $SVG..."
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

# Generate all required sizes
declare -a SIZES=(16 32 128 256 512)

for size in "${SIZES[@]}"; do
    retina=$((size * 2))

    if [ "$CONVERT_CMD" = "rsvg" ]; then
        rsvg-convert -w "$size" -h "$size" "$SVG" -o "$ICONSET/icon_${size}x${size}.png"
        rsvg-convert -w "$retina" -h "$retina" "$SVG" -o "$ICONSET/icon_${size}x${size}@2x.png"
    else
        # sips: render at 1024 first, then resize
        if [ ! -f "$ICONSET/_base.png" ]; then
            sips -s format png "$SVG" --out "$ICONSET/_base.png" &>/dev/null || {
                echo "✗ sips cannot convert this SVG. Install librsvg: brew install librsvg"
                exit 1
            }
        fi
        sips -z "$size" "$size" "$ICONSET/_base.png" --out "$ICONSET/icon_${size}x${size}.png" &>/dev/null
        sips -z "$retina" "$retina" "$ICONSET/_base.png" --out "$ICONSET/icon_${size}x${size}@2x.png" &>/dev/null
    fi
done

# Clean up temp file
rm -f "$ICONSET/_base.png"

echo "▶ Converting iconset → icns..."
iconutil -c icns "$ICONSET" -o "$ICNS"

# Clean up iconset
rm -rf "$ICONSET"

echo "✓ Generated: $ICNS"
echo ""
echo "Rebuild the app bundle to use the new icon:"
echo "  ./scripts/build-bundle.sh"
