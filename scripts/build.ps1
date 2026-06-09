#!/usr/bin/env pwsh
# toolkit/scripts/build.ps1
# Build every local76 repo in the right dependency order.
# Usage: pwsh ./toolkit/scripts/build.ps1 [-SkipLibrary] [-SkipScreensavers] [-SkipApps] [-Release]

param(
    [switch]$SkipLibrary = $false,
    [switch]$SkipScreensavers = $false,
    [switch]$SkipApps = $false,
    [switch]$Release = $true
)

$ErrorActionPreference = "Stop"
$buildFlag = if ($Release) { "--release" } else { "" }

# toolkit/ lives at <monorepo>/toolkit. The sibling repos are in the same monorepo root.
$monorepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$libPath    = Join-Path $monorepoRoot "library"
$screensPath = Join-Path $monorepoRoot "screensavers"
$apps = @("helm", "pulse", "scout", "trance", "ignite")

function Build-One {
    param([string]$Path, [string]$Name)
    Write-Host "=== Building $Name ===" -ForegroundColor Cyan
    Push-Location $Path
    try {
        cargo build $buildFlag
        if ($LASTEXITCODE -ne 0) {
            throw "cargo build failed in $Name"
        }
    } finally {
        Pop-Location
    }
}

# 1. library FIRST (the [patch] target)
if (-not $SkipLibrary) {
    Build-One $libPath "library"
}

# 2. screensavers (10 effect binaries — depend on library)
if (-not $SkipScreensavers) {
    Build-One $screensPath "screensavers"
}

# 3. The 5 TUI apps
if (-not $SkipApps) {
    foreach ($a in $apps) {
        $path = Join-Path $monorepoRoot $a
        if (Test-Path $path) {
            Build-One $path $a
        }
    }
}

Write-Host ""
Write-Host "All builds complete." -ForegroundColor Green
