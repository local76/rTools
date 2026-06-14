#!/usr/bin/env pwsh
# release-check.ps1 — gate for the daily release.
#
# For each cargo repo in the monorepo, fetch origin and ask: is
# origin/main ahead of the most recent v<date> tag? Returns 0 if at
# least one repo has new commits, 1 if all are at HEAD.

param(
    [string]$MonorepoRoot = (Resolve-Path "$PSScriptRoot/../..")
)

$ErrorActionPreference = "Stop"

$repos = @(
    "library",
    "app-helm", "app-pulse", "app-scout", "app-ignite",
    "screensaver-beams", "screensaver-bounce", "screensaver-bursts",
    "screensaver-chaos", "screensaver-cosmos", "screensaver-disco",
    "screensaver-flame", "screensaver-glyphs", "screensaver-gnats",
    "screensaver-storm"
)

$anyNew = $false

foreach ($repo in $repos) {
    $dir = Join-Path $MonorepoRoot $repo
    if (-not (Test-Path "$dir/Cargo.toml")) {
        Write-Host "[skip] $repo (not found)" -ForegroundColor DarkGray
        continue
    }
    Push-Location $dir
    try {
        git fetch origin --quiet 2>&1 | Out-Null
        $latestTag = git describe --tags --abbrev=0 origin/main 2>$null
        if (-not $latestTag) {
            Write-Host "[new ] $repo (no tags found, needs initial release)" -ForegroundColor Yellow
            $anyNew = $true
            continue
        }
        $tagCommit = git rev-list -n 1 "$latestTag" 2>$null
        $headCommit = git rev-parse origin/main 2>$null
        if ($tagCommit -eq $headCommit) {
            Write-Host "[skip] $repo (at $latestTag)" -ForegroundColor DarkGray
        } else {
            $commitsAhead = (git rev-list --count "$latestTag..origin/main" 2>$null)
            Write-Host "[new ] $repo ($commitsAhead commits since $latestTag)" -ForegroundColor Green
            $anyNew = $true
        }
    } finally {
        Pop-Location
    }
}

if ($anyNew) {
    exit 0
} else {
    Write-Host "No new commits since last release. Skipping." -ForegroundColor Cyan
    exit 1
}
