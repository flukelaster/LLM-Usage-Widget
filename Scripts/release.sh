#!/usr/bin/env bash
#
# release.sh - build an optimized release .app and wrap it in a drag-to-Applications .dmg.
#
# This produces an AD-HOC signed build (no Apple Developer ID on this machine). It runs fine
# locally and when shared, but the FIRST launch on another Mac needs a one-time Gatekeeper bypass
# (right-click > Open, or `xattr -dr com.apple.quarantine <app>`). For a clean, no-warning build,
# get an Apple Developer ID and run Scripts/notarize.sh instead.

set -euo pipefail

APP_NAME="UsageWidget"
DMG_NAME="LLM-Usage-Widget"
VOL_NAME="LLM Usage Widget"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if [[ ! -f "${ROOT}/Resources/AppIcon.icns" ]]; then
  echo "==> Generating app icon..."
  "${ROOT}/Scripts/make_icon.sh"
fi

echo "==> Building release .app..."
"${ROOT}/Scripts/package_app.sh" release

DIST="${ROOT}/dist"
mkdir -p "${DIST}"
DMG_PATH="${DIST}/${DMG_NAME}.dmg"
rm -f "${DMG_PATH}"

STAGE="$(mktemp -d)"
cp -R "${ROOT}/${APP_NAME}.app" "${STAGE}/"
ln -s /Applications "${STAGE}/Applications"

echo "==> Creating .dmg..."
hdiutil create -volname "${VOL_NAME}" -srcfolder "${STAGE}" -ov -format UDZO "${DMG_PATH}" >/dev/null
rm -rf "${STAGE}"

SIZE="$(du -h "${DMG_PATH}" | cut -f1)"
echo ""
echo "OK: wrote ${DMG_PATH} (${SIZE})"
echo ""
echo "To install: open the .dmg and drag ${APP_NAME} to Applications."
echo "First launch on another Mac (ad-hoc signed): right-click the app > Open, or run:"
echo "  xattr -dr com.apple.quarantine \"/Applications/${APP_NAME}.app\""
