#!/usr/bin/env bash
# Build and install the release app for the current user.
set -euo pipefail
cd "$(dirname "$0")/.."

app="$(./scripts/bundle-app.sh release)"
destination="$HOME/Applications/ScarlettMidiControl.app"

killall ScarlettMidiControl 2>/dev/null || true
mkdir -p "$HOME/Applications"
ditto "$app" "$destination"
open "$destination"

echo "Installed and launched $destination"
echo "To launch at login, add this app in System Settings → General → Login Items & Extensions → Open at Login."
