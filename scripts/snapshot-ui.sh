#!/usr/bin/env bash
# Render the mixer chrome to a PNG via SwiftUI ImageRenderer (no menu-bar click required).
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-.build/snapshots/mixer.png}"
mkdir -p "$(dirname "$OUT")"

swift build -c debug --disable-sandbox --product ScarlettMidiControl
.build/debug/ScarlettMidiControl --snapshot "$(pwd)/$OUT"
echo "Snapshot: $OUT"
