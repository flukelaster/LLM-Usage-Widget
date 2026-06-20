# LLM Usage Widget — Windows

A Windows port of the macOS menu-bar app, built with **.NET 10 + [Avalonia](https://avaloniaui.net/)**.
It lives in the **system tray**: click the gauge for a popover with per-provider usage bars, reset
countdowns, plan badges, and near-limit status — the same design as the macOS app.

<div align="center">
  <img src="../docs/windows-screenshot.png" alt="Windows popover" width="320">
</div>

## Layout

```
windows/
  src/Core/    Platform-agnostic core (no UI): domain models, provider parsers,
               OAuth clients, HTTP fetchers, DPAPI token store, and the polling engine.
  src/App/     Avalonia tray app: theming, view-models, the popover, and sign-in windows.
  tests/       xunit suite mirroring the macOS app's self-checks (parsing, PKCE, JWT, …).
```

The `Core` project is shared, UI-free, and fully unit-tested. `App` is the Avalonia front end.

## Requirements

- [.NET SDK 10](https://dotnet.microsoft.com/download) (LTS-class). On macOS: `brew install dotnet`.
- Building the **app** works on any OS (Avalonia is cross-platform); the produced executable targets
  Windows 10/11 x64.

## Build, test, run

```bash
cd windows
dotnet test                                   # run the core unit tests
dotnet build                                  # build the whole solution

# Render the popover UI to a PNG (headless — works on any OS, mirrors the macOS --snapshot):
dotnet src/App/bin/Debug/net10.0/LLMUsageWidget.App.dll --snapshot out.png
```

On **Windows**, run the tray app with `dotnet run --project src/App`.

## Package a Windows executable

```powershell
pwsh windows/publish.ps1        # → windows/dist/win-x64/LLMUsageWidget.App.exe (self-contained)
```

This emits a **self-contained, single-file** `.exe` (bundles the .NET runtime + Skia), so it runs on
a clean Windows machine with nothing pre-installed. The same `dotnet publish` command also works from
macOS/Linux to cross-build the Windows binary.

## How auth & storage map to Windows

| Concern | Implementation |
|---|---|
| Token storage | `FileTokenStore` — encrypted with **Windows DPAPI** (per-user) under `%APPDATA%\LLMUsageWidget` |
| Codex loopback OAuth | `HttpListener` on `127.0.0.1:1455` |
| Claude / Copilot sign-in | Paste-code window / device-code window |
| Open browser | `Process.Start(UseShellExecute = true)` |

The provider endpoints, OAuth client IDs, and parsing logic are identical to the macOS app.

## Status

Done: core (tested), themed popover UI, OAuth + providers + polling engine, tray + sign-in, and
self-contained packaging. Not yet ported from macOS: the **Settings** window (menu-bar focus, poll
interval, notifications), **launch-at-login** (HKCU `Run`), and **toast notifications**.
