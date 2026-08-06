#!/usr/bin/env bash
set -euo pipefail

PWD_DIR=$(pwd)
DIST_DIR="$PWD_DIR/dist"
APP_NAME="Commander"
APP_BUNDLE="$DIST_DIR/${APP_NAME}.app"
VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "0.0.0")

if [ ! -d "$APP_BUNDLE" ]; then
  echo "App bundle not found at $APP_BUNDLE" >&2
  exit 1
fi

mkdir -p "$DIST_DIR/packages"

DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
echo "Creating DMG at $DMG_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$APP_BUNDLE" -ov -format UDZO "$DMG_PATH"

PKG_PATH="$DIST_DIR/packages/${APP_NAME}.pkg"
echo "Creating PKG at $PKG_PATH"
PKGROOT="$DIST_DIR/pkgroot"
rm -rf "$PKGROOT"
mkdir -p "$PKGROOT/Applications"
cp -R "$APP_BUNDLE" "$PKGROOT/Applications/"

pkgbuild --root "$PKGROOT" --identifier "com.commander.app" --version "$VERSION" --install-location "/" "$PKG_PATH"

echo "Artifacts:"
ls -l "$DMG_PATH" "$PKG_PATH"

echo "Done"
