#!/usr/bin/env bash
#
# notarize.sh - sign with a Developer ID + hardened runtime, notarize, and staple.
# Requires an Apple Developer account (paid). Not runnable without a Developer ID Application cert.
#
# Usage:
#   DEV_ID="Developer ID Application: Your Name (TEAMID)" \
#   APPLE_ID="you@example.com" TEAM_ID="TEAMID" APP_PW="app-specific-password" \
#   Scripts/notarize.sh
#
# Get APP_PW from appleid.apple.com > Sign-In and Security > App-Specific Passwords.
# After this succeeds, run Scripts/release.sh to wrap the notarized .app in a .dmg.

set -euo pipefail

APP_NAME="UsageWidget"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

: "${DEV_ID:?set DEV_ID to your 'Developer ID Application: Name (TEAMID)' identity}"
: "${APPLE_ID:?set APPLE_ID to your Apple ID email}"
: "${TEAM_ID:?set TEAM_ID to your Apple Developer team id}"
: "${APP_PW:?set APP_PW to an app-specific password}"

echo "==> Building release .app..."
"${ROOT}/Scripts/package_app.sh" release

APP="${ROOT}/${APP_NAME}.app"
echo "==> Signing with Developer ID + hardened runtime..."
codesign --force --options runtime --timestamp --sign "${DEV_ID}" "${APP}"
codesign --verify --strict --verbose=2 "${APP}"

DIST="${ROOT}/dist"
mkdir -p "${DIST}"
ZIP="${DIST}/${APP_NAME}-notarize.zip"
/usr/bin/ditto -c -k --keepParent "${APP}" "${ZIP}"

echo "==> Submitting to notarytool (a few minutes)..."
xcrun notarytool submit "${ZIP}" --apple-id "${APPLE_ID}" --team-id "${TEAM_ID}" --password "${APP_PW}" --wait

echo "==> Stapling the ticket..."
xcrun stapler staple "${APP}"
rm -f "${ZIP}"

echo "OK: ${APP_NAME}.app is signed + notarized + stapled."
echo "Now run Scripts/release.sh to produce a distributable .dmg (drop its ad-hoc re-sign step first if you edit it)."
