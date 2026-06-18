#!/usr/bin/env bash
#
# run.sh - (re)build, package, and launch the app for local development.
#
# Usage: Scripts/run.sh [debug|release]   (default: debug)

set -euo pipefail

APP_NAME="UsageWidget"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-debug}"

"${ROOT}/Scripts/package_app.sh" "${CONFIG}"

# Stop any previous instance, then relaunch the freshly packaged bundle.
killall "${APP_NAME}" 2>/dev/null || true
sleep 0.3
open "${ROOT}/${APP_NAME}.app"

echo "OK: launched ${APP_NAME}. Look in the menu bar (top-right of the screen)."
