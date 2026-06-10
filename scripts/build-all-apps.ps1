#!/usr/bin/env pwsh
# toolkit/scripts/build-all-apps.ps1
# Orchestrates compiling all 5 UI applications (helm, pulse, scout, trance, ignite)
# in the local76 monorepo.
#
# Usage:
#   pwsh ./toolkit/scripts/build-all-apps.ps1
#   pwsh ./toolkit/scripts/build-all-apps.ps1 -Release

param(
    [switch]$Release = $false
)

$ErrorActionPreference = "Stop"

$monorepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$apps = @("helm", "pulse", "scout", "trance", "ignite")

$buildArgs = @()
if ($Release) {
    $buildArgs += "--release"
}

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Building all 5 UI apps (Release=$Release)" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

$step = 0
$total = $apps.Count
$failed = @()

foreach ($app in $apps) {
    $step++
    $appDirName = "app-$app"
    $appPath = Join-Path $monorepoRoot $appDirName
    if (-not (Test-Path $appPath)) {
        # Fallback to unprefixed directory name
        $appPath = Join-Path $monorepoRoot $app
    }

    Write-Host "`n[$step/$total] Building $appDirName at $appPath..." -ForegroundColor Cyan

    if (-not (Test-Path $appPath)) {
        Write-Host "  Error: Path not found: $appPath" -ForegroundColor Red
        $failed += $app
        continue
    }

    Push-Location $appPath
    try {
        cargo build @buildArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Error: Build failed for $app" -ForegroundColor Red
            $failed += $app
        } else {
            Write-Host "  Success: $app built successfully" -ForegroundColor Green
        }
    } catch {
        Write-Host "  Exception occurred while building ${app}: $_" -ForegroundColor Red
        $failed += $app
    } finally {
        Pop-Location
    }
}

Write-Host "`n==========================================" -ForegroundColor Green
if ($failed.Count -eq 0) {
    Write-Host "All 5 UI apps compiled successfully!" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Build failed for the following apps: $($failed -join ', ')" -ForegroundColor Red
    Write-Host "==========================================" -ForegroundColor Green
    exit 1
}
