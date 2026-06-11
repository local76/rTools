#!/usr/bin/env pwsh
# daily-release.ps1 — the daily 04:00 PT release orchestrator.
#
# Runs:
#   1. release-check.ps1  (gate: any new commits?)
#   2. compile-local-development.ps1  (build everything)
#   3. tag-each-repo-with-crate-version.ps1  (tag)
#   4. push-uniform-git-tag.ps1  (push tag)
#   5. gh release create  (publish to GitHub)
#   6. notify-release.ps1  (toast)
#
# Logs to dist/logs/daily-release-<YYYY-MM-DD>.log

param(
    [string]$MonorepoRoot = (Resolve-Path "$PSScriptRoot/../.."),
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$logDir = Join-Path $MonorepoRoot "dist/logs"
$logFile = Join-Path $logDir "daily-release-$timestamp.log"

if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

function Log($msg) {
    $line = "[$((Get-Date).ToString('HH:mm:ss'))] $msg"
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

Log "=== daily-release starting ==="
Log "Monorepo: $MonorepoRoot"
Log "Log file: $logFile"

# 1. Gate
Log "Step 1/6: release-check"
$checkScript = Join-Path $PSScriptRoot "release-check.ps1"
& pwsh $checkScript 2>&1 | ForEach-Object { Log $_ }
if ($LASTEXITCODE -ne 0 -and -not $Force) {
    Log "No new commits. Exiting."
    exit 0
}

# 2. Build
Log "Step 2/6: compile-local-development"
$buildScript = Join-Path $MonorepoRoot "toolkit/scripts/compile-local-development.ps1"
& pwsh $buildScript 2>&1 | ForEach-Object { Log $_ }
if ($LASTEXITCODE -ne 0) {
    Log "Build failed. Aborting release."
    & pwsh (Join-Path $PSScriptRoot "notify-release.ps1") -Kind "failure" -Message "Build failed at $(Get-Date -Format 'HH:mm')"
    exit 1
}

# 3. Tag
Log "Step 3/6: tag-each-repo-with-crate-version"
$tagScript = Join-Path $MonorepoRoot "toolkit/tag-each-repo-with-crate-version.ps1"
& pwsh $tagScript 2>&1 | ForEach-Object { Log $_ }

# 4. Read the version that was just tagged
$version = (Get-Content (Join-Path $MonorepoRoot "library/Cargo.toml") |
    Select-String -Pattern '^version\s*=\s*"([^"]+)"').Matches[0].Groups[1].Value
$tag = "v$version"
Log "Step 4/6: push tag $tag"

$pushScript = Join-Path $MonorepoRoot "toolkit/scripts/push-uniform-git-tag.ps1"
& pwsh $pushScript -Tag $tag 2>&1 | ForEach-Object { Log $_ }

# 5. Publish
Log "Step 5/6: gh release create"
$distBin = Join-Path $MonorepoRoot "dist/binaries"
$distDeb = Join-Path $MonorepoRoot "dist/debs"
$assets = @()
if (Test-Path $distBin) {
    $assets += Get-ChildItem -Path $distBin -Recurse -File | Select-Object -ExpandProperty FullName
}
if (Test-Path $distDeb) {
    $assets += Get-ChildItem -Path $distDeb -Recurse -File | Select-Object -ExpandProperty FullName
}

if ($assets.Count -eq 0) {
    Log "No assets found in dist/binaries or dist/debs. Skipping release publish."
} else {
    # Fix for C3: do NOT build a shell string and pass it through Invoke-Expression.
    # Asset paths can contain quotes, backticks, semicolons, or $(...) which
    # would be interpreted as shell metacharacters and execute arbitrary code.
    # Instead, pass assets as a native array argument to gh. PowerShell splat
    # @assets here expands to the file paths with no shell interpretation.
    Log "Running: gh release create `"$tag`" --title `"Release $version`" --generate-notes @assets"
    Push-Location $MonorepoRoot
    try {
        $output = gh release create "$tag" --title "Release $version" --generate-notes @assets 2>&1
        $output | ForEach-Object { Log $_ }
    } finally {
        Pop-Location
    }
}

# 6. Notify
Log "Step 6/6: notify"
& pwsh (Join-Path $PSScriptRoot "notify-release.ps1") -Kind "success" -Version $version 2>&1 | ForEach-Object { Log $_ }

Log "=== daily-release complete ==="
exit 0
