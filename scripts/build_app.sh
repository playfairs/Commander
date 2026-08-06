#!/usr/bin/env bash
set -euo pipefail

VERSION=${1:-}
BUILD_DIR=${2:-build}
APP_NAME="Commander"
BUNDLE_ID="dev.playfairs.Commander"

if [ -z "${VERSION}" ]; then
  VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")
fi

echo "Building ${APP_NAME} (version ${VERSION}) into ${BUILD_DIR}..."

swift build -c release

BIN_PATH=".build/release/${APP_NAME}"
if [ ! -f "${BIN_PATH}" ]; then
  echo "Build output not found at ${BIN_PATH}" >&2
  exit 1
fi

APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RESOURCES_DIR="${CONTENTS}/Resources"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

cat > "${CONTENTS}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
</dict>
</plist>
EOF

xattr -c "${APP_DIR}" 2>/dev/null || true

echo "Created ${APP_DIR}"
