# build_everything.ps1 — build all rApps + rScenes + rCommon in the right dependency order
#
# Run from the local76/ root (this script is the one in rTools/ but the
# canonical "build all" entry point is the symlink/copy in the local76/
# root, which the user invokes).
#
# This script assumes the standard sibling layout:
#   local76/
#   ├── rCommon/   (the shared design system + 10 screensaver effects)
#   ├── rScenes/   (the 10 standalone screensaver shim binaries)
#   ├── rFetch/
#   ├── rIdle/
#   ├── rMonitor/
#   ├── rStartup/
#   ├── rTemplate/
#   └── rWifi/
#
# All paths are derived from $PSScriptRoot's parent's parent, so the
# script works regardless of which directory the user invokes it from.

param(
    [switch]$SkipCommon = $false,
    [switch]$SkipScenes = $false,
    [switch]$SkipApps = $false,
    [switch]$Release = $true
)

$ErrorActionPreference = "Stop"
$local76 = (Resolve-Path "$PSScriptRoot/../..").Path
Write-Host "local76 root: $local76" -ForegroundColor Cyan

function Invoke-Step {
    param($N, $Total, $Name, $Path, $Script)
    Write-Host "`n[$N/$Total] Building $Name..." -ForegroundColor Yellow
    Push-Location $Path
    try {
        & $Script
        if ($LASTEXITCODE -ne 0) {
            throw "$Name build failed (exit $LASTEXITCODE)"
        }
        Write-Host "[SUCCESS] $Name" -ForegroundColor Green
    } finally {
        Pop-Location
    }
}

$buildFlag = if ($Release) { "--release" } else { "" }
$apps = @("rFetch", "rIdle", "rMonitor", "rStartup", "rTemplate", "rWifi")
$total = ($apps.Count) + 2  # +2 for rCommon + rScenes
$step = 0

if (-not $SkipCommon) {
    $step++
    Invoke-Step $step $total "rCommon" "$local76/rCommon" {
        cargo build $buildFlag
    }
}

if (-not $SkipApps) {
    foreach ($app in $apps) {
        $step++
        $script = if (Test-Path "$local76/$app/build_all.ps1") {
            { & "$local76/$app/build_all.ps1" }
        } else {
            { cargo build $buildFlag }
        }
        Invoke-Step $step $total $app "$local76/$app" $script
    }
}

if (-not $SkipScenes) {
    $step++
    Invoke-Step $step $total "rScenes (10 screensaver shims)" "$local76/rScenes" {
        cargo build --workspace $buildFlag
    }
}

Write-Host "`nAll build processes completed successfully." -ForegroundColor Green
