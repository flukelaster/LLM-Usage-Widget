<div align="center">

<img src="docs/cover.png" alt="LLM Usage Widget — real-time usage limits for Claude, Codex and GitHub Copilot, live in your macOS menu bar" width="100%">

<h1>LLM Usage Widget</h1>

<p><strong>A native macOS menu-bar app showing real-time usage limits for your main LLM tools —
<a href="https://claude.ai">Claude</a>, <a href="https://chatgpt.com">Codex</a>, and
<a href="https://github.com/features/copilot">GitHub Copilot</a>.</strong></p>

<p>It surfaces your usage windows the way Claude Desktop does: a glanceable percentage in the
menu bar, and a click-away popover with usage bars, reset countdowns, and near-limit alerts.</p>

[![Download latest .dmg](https://img.shields.io/badge/Download-latest%20.dmg-2EA043?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/flukelaster/LLM-Usage-Widget/releases/latest)

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-0B1120?logo=apple&logoColor=white)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-243049)
![Swift 6](https://img.shields.io/badge/Swift-6-FA7343?logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-native-1E293B)
![Windows](https://img.shields.io/badge/Windows-.NET%2010%20%2B%20Avalonia-0B1120?logo=windows&logoColor=white)

<sub>A **Windows** port (.NET 10 + Avalonia, same design and providers) lives in [`windows/`](windows/README.md).</sub>

</div>

---

## Features

<table>
<tr><td width="58%" valign="top">

Click the menu-bar gauge to see, per provider:

- **5-hour and weekly usage bars**, each with the percentage used and a reset countdown.
- **Threshold colors** — green below 60%, amber 60–85%, red above 85%.
- **Plan badge** (Max / Pro / Plus …) and an *up to date / rate-limited / stale* status.
- **A live percentage in the menu bar** — by default the provider closest to its limit, or pin a specific provider in Settings.
- **Near-limit notifications** when any window crosses 90% (once per window, per reset cycle).
- **In-app OAuth** (PKCE) — tokens are stored only in your macOS Keychain.

</td><td width="42%" valign="top" align="center">

<img src="docs/screenshot.png" alt="Popover showing Claude, Codex and Copilot usage" width="300">

</td></tr>
</table>

## Installation

Download the latest disk image from the
[**Releases**](https://github.com/flukelaster/LLM-Usage-Widget/releases/latest) page and drag the
app into **Applications**. Requires macOS 14 (Sonoma) or later on Apple Silicon.

> [!NOTE]
> The build is ad-hoc signed (no Apple Developer ID), so the **first launch** needs a one-time
> Gatekeeper step: right-click the app and choose **Open**, then confirm. See
> [Distribution](#distribution) for the details and the notarization path.

The app is menu-bar-only (`LSUIElement`, no Dock icon) — look for the gauge in the top-right of the
menu bar.

## Building from source

**Requirements:** macOS 14 (Sonoma) or later, and a Swift 6 toolchain. The Command Line Tools are
sufficient — full Xcode is not required.

```bash
./Scripts/run.sh                   # build (debug) → package UsageWidget.app → launch
./Scripts/package_app.sh release   # build the release .app bundle only
```

## Signing in

Open the popover and click **Sign in** on a provider card:

| Provider | Authentication flow |
|---|---|
| **Codex** | Opens your browser to OpenAI; a local listener on `127.0.0.1:1455` captures the redirect automatically — nothing to paste. |
| **Claude** | Opens your browser to Anthropic, which shows a code (`abc123#xyz`). Paste it back into the card. Anthropic rejects arbitrary loopback redirects, so this paste step is required. |
| **Copilot** | Uses GitHub's device flow: the card shows a short code; enter it at `github.com/login/device` (opened for you) and the app finishes automatically. |

Providers (enable / disable, sign out), poll interval, **menu-bar focus and display**, near-limit
notifications, and **Launch at login** are all managed from **Settings** in the footer of the popover.

## How it works

Each provider exposes the same usage endpoint its own first-party client uses:

| Provider | Endpoint | Notes |
|---|---|---|
| Claude | `GET api.anthropic.com/api/oauth/usage` | The endpoint Claude Code's `/usage` uses. Requires the `anthropic-beta` header and a `claude-code/<ver>` User-Agent. Rate-limits hard, so it is polled at most every 5 minutes with exponential backoff. |
| Codex | `GET chatgpt.com/backend-api/wham/usage` | Returns the primary (5-hour) and secondary (weekly) windows. |
| Copilot | `GET api.github.com/copilot_internal/user` | Monthly premium-request quota (`quota_snapshots`) and reset date. |

Claude's `/usage` endpoint carries no plan, so the **Max / Pro** badge comes from a separate profile
endpoint (`GET api.anthropic.com/api/oauth/profile`) that is fetched once and cached on the token.

The last-good snapshot is cached to `~/Library/Application Support/com.flukelaster.usagewidget/`,
so the popover shows data instantly and never blanks out on a failed refresh.

> [!WARNING]
> These endpoints and the first-party OAuth client IDs are **undocumented and unofficial**, and may
> change without notice. The app reads only **your own** subscription usage and never automates
> inference. Use is a gray area under each vendor's terms. It degrades gracefully if an endpoint
> changes — falling back to cached data with a clear error, never a crash.

Gemini and Cursor were evaluated but deferred: Gemini's individual CLI usage API is mid-migration to
Antigravity, and Cursor requires reading the editor's local SQLite with full-disk access and has no
per-user official API.

## Development

```bash
swift build                                   # compile
.build/debug/UsageWidget --check              # run the logic self-checks (parsing, PKCE, backoff, …)
.build/debug/UsageWidget --snapshot out.png   # render the popover UI to a PNG (DEBUG)
```

The Command Line Tools toolchain ships neither XCTest nor swift-testing, so the test suite is an
in-process self-check run via `--check`. Add an XCTest or swift-testing target once full Xcode is
installed if desired.

Regenerate the app icon after design tweaks with `./Scripts/make_icon.sh` (renders the SwiftUI icon
to `Resources/AppIcon.icns`). Regenerate this README's cover image with `node Scripts/make_cover.mjs`.

## Architecture

```
Sources/UsageWidget/
  App/         @main entry, AppDelegate, composition root, snapshot/self-check runners
  MenuBar/     menu-bar label and popover root
  Domain/      UsageProvider protocol and unified models (LimitWindow, ProviderUsage, …)
  Providers/   Claude/, Codex/, Copilot/ — OAuth clients, usage fetchers, orchestration
  Auth/        PKCE, Keychain, TokenStore, loopback OAuth server
  Engine/      UsageStore (@Observable), RefreshScheduler, BackoffPolicy, SnapshotCache
  Settings/    SettingsModel/View, LaunchAtLogin (SMAppService)
  Views/       design tokens, provider card, limit-window bar, states, Claude mascot
  Diagnostics/ SelfChecks
```

## Distribution

Build a distributable disk image:

```bash
./Scripts/release.sh      # → dist/LLM-Usage-Widget.dmg (drag-to-Applications installer)
```

The build is **arm64 (Apple Silicon)** and **ad-hoc signed** — there is no Apple Developer ID on
this machine, and a universal arm64 + x86_64 build would require full Xcode (`xcbuild`). It runs
fine when shared, but the **first launch on another Mac** needs a one-time Gatekeeper bypass:

- Right-click the app and choose **Open** (then confirm), or
- `xattr -dr com.apple.quarantine "/Applications/UsageWidget.app"`

For a clean, no-warning build — recommended if you distribute widely — get an Apple Developer ID
($99/year) and notarize. `Scripts/notarize.sh` performs the Developer-ID signing, hardened runtime,
`notarytool` submission, and staple:

```bash
DEV_ID="Developer ID Application: Your Name (TEAMID)" \
APPLE_ID="you@example.com" TEAM_ID="TEAMID" APP_PW="app-specific-password" \
./Scripts/notarize.sh        # then ./Scripts/release.sh to wrap it in a .dmg
```
