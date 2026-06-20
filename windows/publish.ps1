# Build a self-contained, single-file Windows x64 executable.
#   pwsh windows/publish.ps1
# (Also works cross-platform — the same `dotnet publish` runs on macOS/Linux and emits a Windows .exe.)
$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

dotnet publish src/App/LLMUsageWidget.App.csproj `
  -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=true `
  -p:IncludeNativeLibrariesForSelfExtract=true `
  -p:DebugType=none `
  -o dist/win-x64

Write-Host ""
Write-Host "OK: dist/win-x64/LLMUsageWidget.App.exe"
Write-Host "It's a tray app — launch it and look for the gauge icon in the Windows system tray."
