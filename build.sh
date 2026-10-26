#!/bin/zsh
# Build MirrorDesk.app from source.
# Requires Xcode command line tools. Downloads the official scrcpy macOS
# arm64 release, verifies its SHA-256, compiles the app, generates the icon,
# and ad-hoc signs the bundle.
set -e

APP=MirrorDesk.app
SCRCPY_VER=v5.0.1
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bin" "$APP/Contents/Resources/scrcpy"

cp Resources/Info.plist "$APP/Contents/Info.plist"
swiftc -O Sources/main.swift -o "$APP/Contents/MacOS/MirrorDesk" -framework Cocoa

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

curl -sL "https://github.com/Genymobile/scrcpy/releases/download/$SCRCPY_VER/scrcpy-macos-aarch64-$SCRCPY_VER.tar.gz" -o "$TMP/s.tar.gz"
curl -sL "https://github.com/Genymobile/scrcpy/releases/download/$SCRCPY_VER/SHA256SUMS.txt" -o "$TMP/SHA256SUMS.txt"

EXPECTED=$(grep "scrcpy-macos-aarch64-$SCRCPY_VER.tar.gz" "$TMP/SHA256SUMS.txt" | awk '{print $1}')
ACTUAL=$(shasum -a 256 "$TMP/s.tar.gz" | awk '{print $1}')
if [[ -z "$EXPECTED" || "$EXPECTED" != "$ACTUAL" ]]; then
  echo "scrcpy checksum verification failed" >&2
  exit 1
fi

tar -xzf "$TMP/s.tar.gz" -C "$TMP"
cp -R "$TMP"/scrcpy-macos-aarch64-*/* "$APP/Contents/Resources/scrcpy/"

# The engine is a nested accessory app (LSUIElement), so only MirrorDesk
# appears in the Dock; the SDL window still belongs to the engine.
ENGINE="$APP/Contents/Resources/Engine/MirrorDeskEngine.app"
mkdir -p "$ENGINE/Contents/MacOS"
cp "$APP/Contents/Resources/scrcpy/scrcpy" "$ENGINE/Contents/MacOS/mirrordesk-engine"
cp Resources/Engine-Info.plist "$ENGINE/Contents/Info.plist"
chmod +x "$ENGINE/Contents/MacOS/mirrordesk-engine"

cp Resources/mirrordesk "$APP/Contents/Resources/bin/mirrordesk"
chmod +x "$APP/Contents/Resources/bin/mirrordesk" \
         "$APP/Contents/Resources/scrcpy/scrcpy" \
         "$APP/Contents/Resources/scrcpy/adb" \
         "$ENGINE/Contents/MacOS/mirrordesk-engine"

swiftc -O scripts/make-icon.swift -o "$TMP/make-icon"
"$TMP/make-icon" "$TMP/MirrorDesk.iconset"
iconutil -c icns "$TMP/MirrorDesk.iconset" -o "$APP/Contents/Resources/MirrorDesk.icns"

codesign --force --sign - "$APP/Contents/Resources/scrcpy/adb"
codesign --force --sign - "$APP/Contents/Resources/scrcpy/scrcpy"
codesign --force --sign - "$ENGINE/Contents/MacOS/mirrordesk-engine"
codesign --force --sign - "$ENGINE"
codesign --force --sign - "$APP/Contents/MacOS/MirrorDesk"
codesign --force --sign - "$APP"

echo "Built $APP"
