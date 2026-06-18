# LLM Usage Widget

A native macOS **menu bar** app that shows **real-time usage limits** for your main LLM CLIs —
**Claude** and **Codex** — the way Claude Desktop surfaces your 5-hour and weekly windows.

Click the menu-bar gauge to see, per provider:

- A big **5-hour** and **weekly** usage bar with **% used** and a **reset countdown**
- Threshold colors: green &lt; 60%, amber 60–85%, red &gt; 85%
- Plan badge (Max / Pro / Plus …) and an "up to date / rate-limited / stale" status
- A live **% in the menu bar** itself (the most-constrained window across providers)

Sign-in is **in-app OAuth** (PKCE). Tokens are stored only in your macOS Keychain.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 6 toolchain (Command Line Tools are enough — full Xcode not required)

## Build & run

```bash
./Scripts/run.sh           # build (debug) → package UsageWidget.app → launch (menu bar, no Dock icon)
./Scripts/package_app.sh release   # just build the release .app bundle
```

The app is menu-bar-only (`LSUIElement`). Look for the gauge icon in the top-right of the menu bar.

## Signing in

Open the popover and click **Sign in** on a provider card:

- **Codex** opens your browser to OpenAI; a tiny local listener on `127.0.0.1:1455` captures the
  redirect automatically — nothing to paste.
- **Claude** opens your browser to Anthropic, which shows a code (`abc123#xyz`). Paste it back into
  the card. (Anthropic rejects arbitrary loopback redirects, so this paste step is required.)

Manage providers (enable/disable, sign out), poll interval, menu-bar display, and **Launch at
login** from **Settings** (footer of the popover).

## Verification

```bash
swift build                                   # compile
.build/debug/UsageWidget --check              # run the logic self-checks (parsing, PKCE, backoff, …)
.build/debug/UsageWidget --snapshot out.png   # render the popover UI to a PNG (DEBUG)
```

> The Command-Line-Tools toolchain ships neither XCTest nor swift-testing, so the test suite is an
> in-process self-check runnable via `--check`. Add an XCTest/Testing target if you install Xcode.

## How it gets the data

| Provider | Endpoint | Notes |
|---|---|---|
| Claude | `GET api.anthropic.com/api/oauth/usage` | The endpoint Claude Code's `/usage` uses. Requires `anthropic-beta` + `claude-code/<ver>` User-Agent. Rate-limits hard → polled ≥ 5 min with exponential backoff. |
| Codex | `GET chatgpt.com/backend-api/wham/usage` | Returns primary (5h) + secondary (weekly) windows. |

The last-good snapshot is cached to `~/Library/Application Support/com.flukelaster.usagewidget/`,
so the popover shows data instantly and never blanks out on a failed refresh.

> ⚠️ **These endpoints and the first-party OAuth client IDs are undocumented / unofficial** and may
> change without notice. This app reads only **your own** subscription usage and never automates
> inference. Use is a gray area under each vendor's terms; it degrades gracefully if an endpoint
> changes (cached data + a clear error, never a crash).

## Project layout

```
Sources/UsageWidget/
  App/        @main entry, AppDelegate, composition root, snapshot/self-check runners
  MenuBar/    menu-bar label + popover root
  Domain/     UsageProvider protocol + unified models (LimitWindow, ProviderUsage, …)
  Providers/  Claude/ and Codex/ — OAuth clients, usage fetchers, provider orchestration
  Auth/       PKCE, Keychain, TokenStore, loopback OAuth server
  Engine/     UsageStore (@Observable), RefreshScheduler, BackoffPolicy, SnapshotCache
  Settings/   SettingsModel/View, LaunchAtLogin (SMAppService)
  Views/      design tokens, provider card, limit-window bar, states
  Diagnostics/ SelfChecks
```

## Distribution

For sharing beyond your own machine, sign with a **Developer ID Application** identity, enable the
hardened runtime, and notarize:

```bash
codesign --force --options runtime --timestamp --sign "Developer ID Application: …" UsageWidget.app
xcrun notarytool submit UsageWidget.zip --apple-id … --team-id … --password … --wait
xcrun stapler staple UsageWidget.app
```
