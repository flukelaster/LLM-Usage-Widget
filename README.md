<div align="center">

<img src="docs/cover.png" alt="LLM Usage Widget — real-time usage limits for Claude, Codex and GitHub Copilot, live in your macOS menu bar" width="100%">

<h1>LLM Usage Widget</h1>

<p><strong>A menu-bar &amp; system-tray app for <b>macOS</b> and <b>Windows</b>, showing real-time
usage limits for your main LLM tools — <a href="https://claude.ai">Claude</a>,
<a href="https://chatgpt.com">Codex</a>, and <a href="https://github.com/features/copilot">GitHub Copilot</a>.</strong></p>

<p>It surfaces your usage windows the way Claude Desktop does: a glanceable percentage in the
menu bar (or Windows tray), and a click-away popover with usage bars, reset countdowns, and near-limit alerts.</p>

[![Download for macOS](https://img.shields.io/badge/Download-macOS%20.dmg-2EA043?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/flukelaster/LLM-Usage-Widget/releases/latest/download/LLM-Usage-Widget.dmg)
&nbsp;
[![Download for Windows](https://img.shields.io/badge/Download-Windows%20.exe-2563EB?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/flukelaster/LLM-Usage-Widget/releases/latest/download/LLM-Usage-Widget-windows-x64.exe)

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-0B1120?logo=apple&logoColor=white)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-arm64-243049)
![Windows 10/11](https://img.shields.io/badge/Windows-10%2F11%20x64-0B1120?logo=windows&logoColor=white)
![Swift 6](https://img.shields.io/badge/Swift-6-FA7343?logo=swift&logoColor=white)
![.NET 10](https://img.shields.io/badge/.NET-10%20%2B%20Avalonia-512BD4?logo=dotnet&logoColor=white)

<sub>macOS is native SwiftUI; the **Windows** build is .NET 10 + Avalonia — see [`windows/`](windows/README.md). Both share the same providers and design.</sub>

</div>

---

## Features

<table>
<tr><td width="54%" valign="top">

Click the menu-bar / tray gauge to see, per provider:

- **5-hour and weekly usage bars**, each with the percentage used and a reset countdown.
- **Threshold colors** — green below 60%, amber 60–85%, red above 85%.
- **Plan badge** (Max / Pro / Plus …) and an *up to date / rate-limited / stale* status.
- **A live percentage in the menu bar** — by default the provider closest to its limit, or pin a specific provider in Settings.
- **Near-limit notifications** when any window crosses 90% (once per window, per reset cycle).
- **In-app OAuth** (PKCE) — tokens are stored only in your OS credential store (macOS Keychain / Windows DPAPI).

</td><td width="46%" valign="top" align="center">

<table align="center">
<tr>
<td align="center"><img src="docs/screenshot.png" alt="macOS popover" width="168"><br><sub><b>macOS</b></sub></td>
<td align="center"><img src="docs/windows-screenshot.png" alt="Windows popover" width="168"><br><sub><b>Windows</b></sub></td>
</tr>
</table>

</td></tr>
</table>

## Installation

Grab the latest build from the
[**Releases**](https://github.com/flukelaster/LLM-Usage-Widget/releases/latest) page:

- **macOS** — download `LLM-Usage-Widget.dmg` and drag the app into **Applications**. Requires
  macOS 14 (Sonoma) or later on Apple Silicon. It's menu-bar-only (`LSUIElement`, no Dock icon) —
  look for the gauge in the top-right of the menu bar.
- **Windows** — download `LLM-Usage-Widget-windows-x64.exe` and run it. Requires Windows 10/11 (x64).
  It's self-contained (no .NET install needed) and lives in the system tray — click the gauge for the
  popover. See [`windows/`](windows/README.md) for details.

> [!NOTE]
> Both builds are ad-hoc / unsigned, so the **first launch** needs a one-time confirmation: on macOS,
> right-click the app → **Open**, then confirm (see [Distribution](#distribution)); on Windows,
> SmartScreen may warn — choose **More info → Run anyway**.

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
