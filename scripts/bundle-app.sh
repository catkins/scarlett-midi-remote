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
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin" "$app/Contents/MacOS/ScarlettMidiControl"

scratch="$(mktemp -d /tmp/scarlett-icon.XXXXXX)"
iconset="$scratch/AppIcon.iconset"
mkdir "$iconset"
for spec in 16:icon_16x16 32:icon_16x16@2x 32:icon_32x32 64:icon_32x32@2x \
            128:icon_128x128 256:icon_128x128@2x 256:icon_256x256 \
            512:icon_256x256@2x 512:icon_512x512 1024:icon_512x512@2x; do
  px="${spec%%:*}"
  name="${spec##*:}"
  sips -z "$px" "$px" Resources/AppIcon.png --out "$iconset/${name}.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
rm -rf "$scratch"

cat > "$app/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>ScarlettMidiControl</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIconName</key>
	<string>AppIcon</string>
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
