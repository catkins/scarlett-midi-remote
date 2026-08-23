#!/usr/bin/env bash
# Build and launch the menu bar app without Xcode.
set -euo pipefail
cd "$(dirname "$0")/.."

app="$(./scripts/bundle-app.sh debug)"
killall ScarlettMidiControl 2>/dev/null || true
open "$app"
echo "Launched menu bar app from $app"
