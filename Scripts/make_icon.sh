#!/usr/bin/env bash
#
# make_icon.sh - render the SwiftUI app icon to a 1024 PNG, then build Resources/AppIcon.icns.
# Run this whenever the icon design changes; package_app.sh picks up the .icns automatically.

set -euo pipefail

APP_NAME="UsageWidget"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

echo "==> Building (debug) for icon rendering..."
swift build -c debug --product "${APP_NAME}" >/dev/null
BIN="$(swift build -c debug --show-bin-path)/${APP_NAME}"

TMP="$(mktemp -d)"
PNG="${TMP}/icon_1024.png"
echo "==> Rendering 1024x1024 icon..."
"${BIN}" --icon "${PNG}"

ICONSET="${TMP}/AppIcon.iconset"
mkdir -p "${ICONSET}"
sips -z 16 16   "${PNG}" --out "${ICONSET}/icon_16x16.png"      >/dev/null
sips -z 32 32   "${PNG}" --out "${ICONSET}/icon_16x16@2x.png"   >/dev/null
sips -z 32 32   "${PNG}" --out "${ICONSET}/icon_32x32.png"      >/dev/null
sips -z 64 64   "${PNG}" --out "${ICONSET}/icon_32x32@2x.png"   >/dev/null
sips -z 128 128 "${PNG}" --out "${ICONSET}/icon_128x128.png"    >/dev/null
sips -z 256 256 "${PNG}" --out "${ICONSET}/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "${PNG}" --out "${ICONSET}/icon_256x256.png"    >/dev/null
sips -z 512 512 "${PNG}" --out "${ICONSET}/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "${PNG}" --out "${ICONSET}/icon_512x512.png"    >/dev/null
cp "${PNG}"     "${ICONSET}/icon_512x512@2x.png"

mkdir -p "${ROOT}/Resources"
iconutil -c icns "${ICONSET}" -o "${ROOT}/Resources/AppIcon.icns"
rm -rf "${TMP}"
echo "OK: wrote Resources/AppIcon.icns"
