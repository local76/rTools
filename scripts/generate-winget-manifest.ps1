#!/usr/bin/env pwsh
# toolkit/scripts/generate-winget-manifest.ps1
# Generates a winget-compliant singleton YAML manifest for local76 applications.
# Usage: pwsh ./toolkit/scripts/generate-winget-manifest.ps1 -App helm -Version 2026.6.9 -MsiPath C:\path\to\helm_v2026.6.9_x64.msi

param(
    [Parameter(Mandatory = $true)]
    [string]$App,

    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$MsiPath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $MsiPath)) {
    Write-Host "Error: MSI file not found at $MsiPath" -ForegroundColor Red
    exit 1
}

# 1. Compute SHA256 of MSI installer
Write-Host "Computing SHA256 hash for $MsiPath..." -ForegroundColor Yellow
$hashResult = Get-FileHash -Path $MsiPath -Algorithm SHA256
$sha256 = $hashResult.Hash.ToLower()

# 2. Get descriptions and tags mapping
$descMap = @{
    "helm" = @("Interactive system information and hardware monitor fetch tool.", "system-fetch", "system-info")
    "pulse" = @("Live system resource, process, and network connection monitor.", "resource-monitor", "activity")
    "scout" = @("WiFi network scanner, channel analyser, and connection diagnostic tool.", "wifi-scanner", "wlan")
    "trance" = @("Standalone terminal screensaver engine and screensaver picker daemon.", "screensaver", "daemon")
    "ignite" = @("Windows startup application manager and boot telemetry logger.", "startup-manager", "windows-boot")
}

$mapped = $descMap[$App]
if (-not $mapped) {
    $mapped = @("Terminal UI utility from local76.", "terminal", "ui")
}

$description = $mapped[0]
$tag1 = $mapped[1]
$tag2 = $mapped[2]

# 3. Build manifest content
$manifestContent = @"
# yaml-language-server: `$schema=https://github.com/microsoft/winget-cli/releases/download/v1.7.10661/singleton.schema.1.7.0.json
PackageIdentifier: local76.$App
PackageVersion: $Version
PackageName: $App
Publisher: local76
License: MIT
Moniker: $App
ShortDescription: $description
Tags:
  - tui
  - rust
  - $tag1
  - $tag2
Installers:
  - Architecture: x64
    InstallerType: wix
    InstallerUrl: https://github.com/local76/$App/releases/download/v$Version/$($App)_v$($Version)_x64.msi
    InstallerSha256: $sha256
ManifestType: singleton
ManifestVersion: 1.7.0
"@

# 4. Save manifest output
$monorepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$wingetPackagingDir = Join-Path $monorepoRoot "toolkit\packaging\winget\$App"
New-Item -ItemType Directory -Force -Path $wingetPackagingDir | Out-Null

$manifestPath = Join-Path $wingetPackagingDir "local76.$App.yaml"
Set-Content -Path $manifestPath -Value $manifestContent -Encoding utf8NoBOM

Write-Host "WinGet Singleton Manifest successfully generated: $manifestPath" -ForegroundColor Green
Write-Host "`nTo test this manifest locally, run the following command:" -ForegroundColor Cyan
Write-Host "winget install --manifest `"$manifestPath`"" -ForegroundColor Yellow
