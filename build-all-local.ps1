# build_everything.ps1 — build all apps + screensavers + library in the right dependency order
#
# Run from the local76/ root (this script is the one in toolkit/ but the
# canonical "build all" entry point is the symlink/copy in the local76/
# root, which the user invokes).
#
# This script assumes the standard sibling layout:
#   local76/
#   ├── library/   (the shared design system + 10 screensaver effects)
#   ├── screensavers/   (the 10 standalone screensaver shim binaries)
#   ├── helm/
#   ├── pulse/
#   ├── ignite/
#   └── scout/
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
$local76 = if (Test-Path "$PSScriptRoot/../library") {
    (Resolve-Path "$PSScriptRoot/..").Path
} else {
    (Resolve-Path "$PSScriptRoot/../..").Path
}
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

$buildArgs = @()
if ($Release) {
    $buildArgs += "--release"
}
$apps = @("helm", "pulse", "ignite", "scout")
$total = $apps.Count + 2  # library + screensavers workspace + apps
$step = 0

if (-not $SkipCommon) {
    $step++
    Invoke-Step $step $total "library" "$local76/library" {
        cargo build @buildArgs
    }
}

if (-not $SkipApps) {
    foreach ($app in $apps) {
        $step++
        $script = { cargo build @buildArgs }
        $appPath = "$local76/app-$app"
        if (-not (Test-Path $appPath)) { $appPath = "$local76/$app" }
        Invoke-Step $step $total $app $appPath $script
    }
}

if (-not $SkipScenes) {
    $step++
    $script = { cargo build @buildArgs }
    $sPath = "$local76/screensavers"
    Invoke-Step $step $total "screensavers" $sPath $script
}

Write-Host "`nAll build processes completed successfully." -ForegroundColor Green
