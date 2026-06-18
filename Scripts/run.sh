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

# Stop any previous instance, then relaunch the freshly packaged bundle. We must wait for the old
# process to actually exit: `open` on an already-running app just activates it (keeping the stale
# binary) instead of launching the new build.
killall "${APP_NAME}" 2>/dev/null || true
for _ in $(seq 1 15); do
  pgrep -x "${APP_NAME}" >/dev/null || break
  sleep 0.2
done
if pgrep -x "${APP_NAME}" >/dev/null; then killall -9 "${APP_NAME}" 2>/dev/null || true; sleep 0.3; fi
open "${ROOT}/${APP_NAME}.app"

echo "OK: launched ${APP_NAME}. Look in the menu bar (top-right of the screen)."
