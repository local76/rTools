#!/usr/bin/env pwsh
# toolkit/scripts/build.ps1
# Build every local76 repo in the right dependency order.
# Usage: pwsh ./toolkit/scripts/build.ps1 [-SkipLibrary] [-SkipScreensavers] [-SkipApps] [-Release]

param(
    [switch]$SkipLibrary = $false,
    [switch]$SkipScreensavers = $false,
    [switch]$SkipApps = $false,
    [switch]$Release = $true,
    # Fix for I24: default to a relative path under the script's own root so
    # the script works on any machine (CI, other devs, fresh clones). Callers
    # can still override with -OutputDir. The previous default was a hardcoded
    # path under a specific user's profile, which silently wrote to that path
    # on every other machine.
    [string]$OutputDir = "./dist"
)

$ErrorActionPreference = "Stop"
$buildFlag = if ($Release) { "--release" } else { "" }

# toolkit/ lives at <monorepo>/toolkit. The sibling repos are in the same monorepo root.
$monorepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$libPath    = Join-Path $monorepoRoot "library"
$apps = @("helm", "pulse", "scout", "trance", "ignite")
$screens = @("beams", "bounce", "bursts", "chaos", "cosmos", "disco", "flame", "glyphs", "gnats", "storm")

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
    foreach ($s in $screens) {
        $path = Join-Path $monorepoRoot "screensaver-$s"
        if (Test-Path $path) {
            Build-One $path "screensaver-$s"
        }
    }
}

# 3. The 5 UI apps
if (-not $SkipApps) {
    foreach ($a in $apps) {
        $path = Join-Path $monorepoRoot "app-$a"
        if (-not (Test-Path $path)) {
            $path = Join-Path $monorepoRoot $a
        }
        if (Test-Path $path) {
            Build-One $path "app-$a"
        }
    }
}

# 4. Copy to organized OutputDir if specified
if ($OutputDir) {
    $appDist = Join-Path $OutputDir "app"
    $screensaverDist = Join-Path $OutputDir "screensaver"
    
    # Create target directories
    New-Item -ItemType Directory -Force -Path $appDist | Out-Null
    New-Item -ItemType Directory -Force -Path $screensaverDist | Out-Null
    
    # Copy apps
    if (-not $SkipApps) {
        foreach ($a in $apps) {
            $path = Join-Path $monorepoRoot "app-$a"
            if (-not (Test-Path $path)) {
                $path = Join-Path $monorepoRoot $a
            }
            $exePath = Join-Path $path "target\release\$a.exe"
            if (Test-Path $exePath) {
                Copy-Item -Path $exePath -Destination (Join-Path $appDist "$a.exe") -Force
                Write-Host "Copied $a.exe to $appDist" -ForegroundColor Green
            }
        }
    }
    
    # Copy screensavers
    if (-not $SkipScreensavers) {
        foreach ($s in $screens) {
            $path = Join-Path $monorepoRoot "screensaver-$s"
            $exePath = Join-Path $path "target\release\$s.exe"
            if (Test-Path $exePath) {
                Copy-Item -Path $exePath -Destination (Join-Path $screensaverDist "$s.scr") -Force
                Write-Host "Copied $s.scr to $screensaverDist" -ForegroundColor Green
            }
        }
    }
}

Write-Host ""
Write-Host "All builds complete." -ForegroundColor Green
