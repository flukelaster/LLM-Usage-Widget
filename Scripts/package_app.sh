#!/usr/bin/env bash
#
# package_app.sh - build the SwiftPM executable and wrap it in a proper .app bundle.
#
# A bare SwiftPM executable cannot host a SwiftUI MenuBarExtra correctly: it needs a
# real bundle with an Info.plist (LSUIElement=true to be a menu-bar-only / Dock-less
# agent). This script synthesizes that bundle and ad-hoc code-signs it for local runs.
#
# Usage: Scripts/package_app.sh [debug|release]   (default: debug)

set -euo pipefail

APP_NAME="UsageWidget"
BUNDLE_ID="com.flukelaster.usagewidget"
DISPLAY_NAME="LLM Usage Widget"
VERSION="0.3.0"
BUILD="3"
MIN_OS="14.0"
CONFIG="${1:-debug}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

# NOTE: native arch only (arm64 on Apple Silicon). A universal arm64+x86_64 build needs `xcbuild`,
# which ships with full Xcode — not the Command Line Tools — so it's unavailable here.
echo "==> Building (${CONFIG})..."
swift build -c "${CONFIG}" --product "${APP_NAME}"
BIN_DIR="$(swift build -c "${CONFIG}" --show-bin-path)"
BIN_PATH="${BIN_DIR}/${APP_NAME}"

if [[ ! -f "${BIN_PATH}" ]]; then
  echo "ERROR: built binary not found at ${BIN_PATH}" >&2
  exit 1
fi

APP_DIR="${ROOT}/${APP_NAME}.app"
echo "==> Packaging ${APP_DIR} ..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${BIN_PATH}" "${APP_DIR}/Contents/MacOS/${APP_NAME}"

ICON_ENTRY=""
if [[ -f "${ROOT}/Resources/AppIcon.icns" ]]; then
  cp "${ROOT}/Resources/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
  ICON_ENTRY="  <key>CFBundleIconFile</key>
  <string>AppIcon</string>"
fi

cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${DISPLAY_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD}</string>
  <key>LSMinimumSystemVersion</key>
  <string>${MIN_OS}</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright 2026</string>
${ICON_ENTRY}
</dict>
</plist>
PLIST

echo "==> Code signing (ad-hoc)..."
codesign --force --sign - "${APP_DIR}"

echo "OK: built ${APP_DIR}"
