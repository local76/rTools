#!/usr/bin/env pwsh
# toolkit/scripts/build-msi-installer.ps1
# Automates the generation of WiX MSI installers for local76 UI applications.
# Requires: WiX Toolset (candle/light in PATH) and cargo-wix cargo subcommand.
# Usage: pwsh ./toolkit/scripts/build-msi-installer.ps1 -App helm -Version 2026.6.9

param(
    [Parameter(Mandatory = $true)]
    [string]$App,

    [Parameter(Mandatory = $true)]
    [string]$Version
)

$ErrorActionPreference = "Stop"

$monorepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$appPath = Join-Path $monorepoRoot "app-$App"
if (-not (Test-Path $appPath)) {
    $appPath = Join-Path $monorepoRoot $App
}

if (-not (Test-Path $appPath)) {
    Write-Host "Error: App path not found: $appPath" -ForegroundColor Red
    exit 1
}

Write-Host "=== Building MSI Installer for $App v$Version ===" -ForegroundColor Cyan

# 1. Prerequisite Checks
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

$cargoWixInstalled = cargo wix --version 2>$null
if (-not $cargoWixInstalled) {
    Write-Host "cargo-wix is not installed. Installing now via cargo..." -ForegroundColor Yellow
    cargo install cargo-wix
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install cargo-wix subcommand."
    }
}

$lightCommand = Get-Command light.exe -ErrorAction SilentlyContinue
$candleCommand = Get-Command candle.exe -ErrorAction SilentlyContinue
if (-not $lightCommand -or -not $candleCommand) {
    Write-Warning "WiX Toolset (candle.exe/light.exe) was not found in your PATH."
    Write-Warning "Please download it from https://wixtoolset.org/ and add it to your PATH."
    throw "WiX Toolset prerequisite missing."
}

# 2. WiX configuration initialization if missing
Push-Location $appPath
try {
    $wixDir = Join-Path $appPath "wix"
    if (-not (Test-Path $wixDir)) {
        Write-Host "Initializing WiX template configuration..." -ForegroundColor Yellow
        cargo wix init
        if ($LASTEXITCODE -ne 0) { throw "Failed to initialize wix config" }
    }

    # 3. Compile MSI installer
    Write-Host "Compiling installer via cargo wix..." -ForegroundColor Yellow
    cargo wix --nocapture
    if ($LASTEXITCODE -ne 0) { throw "cargo wix build failed" }

    # 4. Copy resulting MSI to app dist folder
    $distDir = Join-Path $appPath "dist\binaries"
    New-Item -ItemType Directory -Force -Path $distDir | Out-Null

    # Locate generated MSI
    $msiFile = Get-ChildItem -Path "target\wix" -Filter "*.msi" | Select-Object -First 1
    if (-not $msiFile) {
        throw "Could not locate the generated MSI installer in target\wix"
    }

    $destPath = Join-Path $distDir "$($App)_v$($Version)_x64.msi"
    Copy-Item -Path $msiFile.FullName -Destination $destPath -Force
    Write-Host "MSI Installer successfully packaged: $destPath" -ForegroundColor Green

} finally {
    Pop-Location
}
