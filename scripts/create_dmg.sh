#!/usr/bin/env bash
set -euo pipefail

VERSION=${1:-}
BUILD_DIR=${2:-build}
APP_NAME="Commander"

if [ -z "${VERSION}" ]; then
  VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")
fi

APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
DMG_OUT="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"

if [ ! -d "${APP_DIR}" ]; then
  echo "App bundle not found at ${APP_DIR}" >&2
  exit 1
fi

echo "Creating DMG ${DMG_OUT}..."

STAGE_DIR=$(mktemp -d)
trap "rm -rf \"${STAGE_DIR}\"" EXIT

cp -R "${APP_DIR}" "${STAGE_DIR}/"

hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGE_DIR}" -ov -format UDZO "${DMG_OUT}"

echo "Created ${DMG_OUT}"
