#!/usr/bin/env bash
# Bundle ScarlettMidiControl.app from the SwiftPM executable.
# Usage: ./scripts/bundle-app.sh [debug|release]
# Prints the .app path on stdout; logs go to stderr.
set -euo pipefail
cd "$(dirname "$0")/.."

config="${1:-debug}"
case "$config" in
  debug|release) ;;
  *)
    echo "usage: $0 [debug|release]" >&2
    exit 2
    ;;
esac

swift_build=(swift build -c "$config" --product ScarlettMidiControl)
if [[ -z "${BUILDKITE:-}" ]]; then
  swift_build+=(--disable-sandbox)
fi
"${swift_build[@]}" >&2

bin=".build/${config}/ScarlettMidiControl"
app=".build/${config}/ScarlettMidiControl.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin" "$app/Contents/MacOS/ScarlettMidiControl"
cat > "$app/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>ScarlettMidiControl</string>
	<key>CFBundleIdentifier</key>
	<string>com.example.ScarlettMidiControl</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Scarlett MIDI Control</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>© 2026 Scarlett MIDI Control contributors</string>
</dict>
</plist>
EOF

codesign -s - --force "$app" >/dev/null
echo "$app"
