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
#   ├── trance/
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
$apps = @("helm", "trance", "pulse", "ignite", "scout")
$total = ($apps.Count) + 2  # +2 for library + screensavers
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
        Invoke-Step $step $total $app "$local76/$app" $script
    }
}

if (-not $SkipScenes) {
    $step++
    Invoke-Step $step $total "screensavers (10 screensaver shims)" "$local76/screensavers" {
        cargo build --workspace @buildArgs
    }

    # After the screensavers build, verify every .scr in dist/binaries has
    # a valid 4-size ICONDIR. Soft-fails (warns) while the Windows SDK
    # rc.exe 10.0+ ICONDIR-corruption bug is in play; flip back to
    # fail-on-FAIL once a toolchain workaround lands.
    $verifyScript = Join-Path $PSScriptRoot "scripts/verify-icon.ps1"
    $binariesDir  = Join-Path $local76 "screensavers/dist/binaries"
    if (Test-Path -LiteralPath $verifyScript) {
        Write-Host "`n[verify-icon] checking $binariesDir" -ForegroundColor Yellow
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $verifyScript -BinDir $binariesDir
        if ($LASTEXITCODE -ne 0) {
            Write-Warning ("verify-icon reported failures (exit $LASTEXITCODE) — " +
                "this is the known Windows SDK 10.0.26100.0 rc.exe ICONDIR bug, " +
                "see toolkit/CHANGELOG.md and library/docs/ICON_TROUBLESHOOTING.md")
        }
    }
}

Write-Host "`nAll build processes completed successfully." -ForegroundColor Green
