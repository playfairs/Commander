#!/usr/bin/env bash
set -euo pipefail

VERSION=${1:-}
BUILD_DIR=${2:-build}
APP_NAME="Commander"
BUNDLE_ID="dev.playfairs.Commander"

if [ -z "${VERSION}" ]; then
  VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.0")
fi

APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
PKG_OUT="${BUILD_DIR}/${APP_NAME}-${VERSION}.pkg"

if [ ! -d "${APP_DIR}" ]; then
  echo "App bundle not found at ${APP_DIR}" >&2
  exit 1
fi

echo "Creating pkg ${PKG_OUT}..."

pkgbuild --root "${APP_DIR}" \
  --install-location "/Applications/${APP_NAME}.app" \
  --identifier "${BUNDLE_ID}" \
  --version "${VERSION}" \
  "${PKG_OUT}"

echo "Created ${PKG_OUT}"
