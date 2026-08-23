#!/usr/bin/env bash
# Build and launch the menu bar app without Xcode.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c debug --disable-sandbox

APP=".build/debug/ScarlettMidiControl.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/debug/ScarlettMidiControl "$APP/Contents/MacOS/ScarlettMidiControl"
cat > "$APP/Contents/Info.plist" << 'EOF'
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

codesign -s - --force "$APP" >/dev/null
killall ScarlettMidiControl 2>/dev/null || true
open "$APP"
echo "Launched menu bar app from $APP"
