#!/usr/bin/env pwsh
# toolkit/scripts/release.ps1
# Build, package, and publish a release to GitHub for one or all apps.
# Usage: pwsh ./toolkit/scripts/release.ps1 -App helm -Version 1.0.0
#        pwsh ./toolkit/scripts/release.ps1 -All -Version 1.0.0

param(
    [string]$App = "",
    [switch]$All = $false,
    [string]$Version = "",
    [switch]$Draft = $true
)

$ErrorActionPreference = "Stop"

if (-not $Version) {
    Write-Host "Version is required (-Version X.Y.Z)" -ForegroundColor Red
    exit 1
}

$monorepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$apps = @(
    "helm", "pulse", "scout", "trance", "ignite",
    "beams", "bounce", "bursts", "chaos", "cosmos", "disco", "flame", "glyphs", "gnats", "storm",
    "screensavers"
)

if ($All) {
    $targets = $apps
} elseif ($App) {
    if ($App -notin $apps) {
        Write-Host "Unknown app: $App. Valid: $($apps -join ', ')" -ForegroundColor Red
        exit 1
    }
    $targets = @($App)
} else {
    Write-Host "Specify -App <name> or -All" -ForegroundColor Red
    exit 1
}

foreach ($a in $targets) {
    $appPath = Join-Path $monorepoRoot "app-$a"
    if (-not (Test-Path $appPath)) {
        $appPath = Join-Path $monorepoRoot "screensavers-$a"
    }
    if (-not (Test-Path $appPath)) {
        $appPath = Join-Path $monorepoRoot $a
    }
    Write-Host "=== Releasing $a $Version ===" -ForegroundColor Cyan
    Push-Location $appPath
    try {
        # Build release
        cargo build --release
        if ($LASTEXITCODE -ne 0) { throw "build failed" }

        # Collect artifacts
        $distDir = Join-Path $appPath "dist"
        $binDir = Join-Path $distDir "binaries"
        New-Item -ItemType Directory -Force -Path $binDir | Out-Null
        Copy-Item -Path "target\release\$a.exe" -Destination $binDir -Force -ErrorAction SilentlyContinue
        Copy-Item -Path "target\release\$a" -Destination $binDir -Force -ErrorAction SilentlyContinue

        # Build debian package if cargo-deb is available
        if (Get-Command cargo-deb -ErrorAction SilentlyContinue) {
            Write-Host "Building DEB package..." -ForegroundColor Yellow
            cargo deb
            if ($LASTEXITCODE -eq 0) {
                Copy-Item -Path "target/debian/*.deb" -Destination $binDir -Force -ErrorAction SilentlyContinue
            }
        }

        # For screensavers, also copy .scr files
        $isScreensaver = ($a -eq "screensavers" -or $a -in @('beams', 'bounce', 'bursts', 'chaos', 'cosmos', 'disco', 'flame', 'glyphs', 'gnats', 'storm'))
        if ($isScreensaver) {
            Get-ChildItem -Path "target\release" -Filter "*.exe" | ForEach-Object {
                $base = $_.BaseName
                Copy-Item -Path $_.FullName -Destination (Join-Path $binDir "$base.scr") -Force
            }
        }

        # Commit dist + tag
        git add -A
        $null = git diff --cached --quiet
        if ($LASTEXITCODE -ne 0) {
            git commit -m "release: $a $Version"
        }
        git tag -a "v$Version" -m "$a v$Version" 2>$null
        $branch = (git branch --show-current).Trim()
        git push origin $branch --follow-tags
        if ($LASTEXITCODE -ne 0) { throw "push failed" }

        # Create GitHub release
        $assets = Get-ChildItem -Path $binDir -File
        if ($assets) {
            $assetPaths = $assets | ForEach-Object { $_.FullName }
            $ghArgs = @('release','create',"v$Version") + $assetPaths + @('--title',"$a v$Version",'--generate-notes')
            if ($Draft) { $ghArgs += '--draft' }
            & gh @ghArgs
        } else {
            Write-Host "  (no assets found in $binDir)" -ForegroundColor Yellow
        }
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "Release complete." -ForegroundColor Green
