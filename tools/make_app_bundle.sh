#!/usr/bin/env bash
set -euo pipefail

PWD_DIR=$(pwd)
BUILD_DIR="$PWD_DIR/.build/release"
DIST_DIR="$PWD_DIR/dist"
APP_NAME="Commander"
APP_BUNDLE="$DIST_DIR/${APP_NAME}.app"
ICON_DIR="$PWD_DIR/Assets/Icons/icns"

echo "Building release..."
swift build -c release

echo "Preparing app bundle at $APP_BUNDLE"
rm -rf "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

EXECUTABLE_SRC="$BUILD_DIR/$APP_NAME"
if [ ! -f "$EXECUTABLE_SRC" ]; then
  EXECUTABLE_SRC="$PWD_DIR/.build/release/$APP_NAME"
fi
if [ ! -f "$EXECUTABLE_SRC" ]; then
  echo "Executable not found at $EXECUTABLE_SRC" >&2
  exit 1
fi

cp "$EXECUTABLE_SRC" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

if [ -d "$PWD_DIR/Assets" ]; then
  cp -R "$PWD_DIR/Assets" "$APP_BUNDLE/Contents/Resources/Assets"
fi

if [ -d "$ICON_DIR" ]; then
  ICNS_FILE=$(find "$ICON_DIR" -maxdepth 1 -type f -name "*.icns" | head -n1 || true)
  if [ -n "$ICNS_FILE" ]; then
    cp "$ICNS_FILE" "$APP_BUNDLE/Contents/Resources/${APP_NAME}.icns"
    ICON_BASENAME=$(basename "$ICNS_FILE")
  fi
fi

VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "0.0.0")
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.commander.app</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>10.14</string>
  <key>CFBundleIconFile</key>
  <string>${APP_NAME}.icns</string>
</dict>
</plist>
EOF

echo "App bundle created at $APP_BUNDLE"
echo "$DIST_DIR"

echo "Done"
