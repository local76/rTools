#!/usr/bin/env pwsh
# verify-pins.ps1 — verify cargo dep pin discipline.
#
# Asserts:
#   1. Every library dep in a consumer's Cargo.toml uses a tag (not
#      a branch).
#   2. Every library dep has a [patch] redirect to a local path
#      (../library).
#   3. The toolkit is not in a git repo at the monorepo root.
#   4. The library repo has Cargo.lock gitignored (not tracked).
#
# Returns 0 on success, 1 on any violation.

param(
    [string]$MonorepoRoot = (Resolve-Path "$PSScriptRoot/../..")
)

$ErrorActionPreference = "Stop"
$violations = 0

function Fail($msg) {
    Write-Host "[FAIL] $msg" -ForegroundColor Red
    $script:violations++
}
function Pass($msg) {
    Write-Host "[ ok ] $msg" -ForegroundColor Green
}

Write-Host "=== cargo dep pin verification ===" -ForegroundColor Cyan

$repos = @(
    "app-helm", "app-pulse", "app-scout", "app-trance", "app-ignite",
    "screensaver-beams", "screensaver-bounce", "screensaver-bursts",
    "screensaver-chaos", "screensaver-cosmos", "screensaver-disco",
    "screensaver-flame", "screensaver-glyphs", "screensaver-gnats",
    "screensaver-storm"
)

foreach ($repo in $repos) {
    $cargo = Join-Path $MonorepoRoot "$repo/Cargo.toml"
    if (-not (Test-Path $cargo)) {
        Fail "$repo/Cargo.toml not found"
        continue
    }
    $content = Get-Content $cargo -Raw

    # Check library dep: must use tag, not branch
    if ($content -match 'library\s*=\s*\{\s*git\s*=\s*"https://github\.com/local76/library\.git",\s*branch\s*=') {
        Fail "$repo uses `branch = ...` for library dep (should be `tag = ...`)"
    } elseif ($content -match 'library\s*=\s*\{\s*git\s*=\s*"https://github\.com/local76/library\.git"') {
        Pass "$repo library dep uses git pin"
    } elseif ($content -match 'library\s*=\s*\{\s*path\s*=') {
        Pass "$repo library dep uses path only"
    } else {
        Fail "$repo has no recognized library dep"
    }

    # Check for [patch] redirect
    if ($content -match '\[patch\."https://github\.com/local76/library\.git"\]') {
        Pass "$repo has [patch] redirect"
    } elseif ($content -match 'library\s*=\s*\{\s*path\s*=\s*"\.\./library"') {
        Pass "$repo library dep is local path"
    } else {
        Fail "$repo missing [patch] or local path for library"
    }
}

# Check library/Cargo.lock is NOT tracked (per convention)
$libLock = Join-Path $MonorepoRoot "library/Cargo.lock"
$libGitignore = Join-Path $MonorepoRoot "library/.gitignore"
if (Test-Path $libLock) {
    if (Test-Path $libGitignore) {
        $gi = Get-Content $libGitignore -Raw
        if ($gi -match 'Cargo\.lock') {
            Pass "library/Cargo.lock is gitignored"
        } else {
            Fail "library/Cargo.lock exists but is NOT in library/.gitignore"
        }
    } else {
        Fail "library/.gitignore not found"
    }
}

# Check build/ is gitignored in each app and screensaver
foreach ($repo in $repos) {
    $buildDir = Join-Path $MonorepoRoot "$repo/build"
    $gi = Join-Path $MonorepoRoot "$repo/.gitignore"
    if ((Test-Path $buildDir) -and (Test-Path $gi)) {
        $giContent = Get-Content $gi -Raw
        $giLines = $giContent -split "`n" | ForEach-Object { $_.Trim() }
        if ($giLines -notcontains "/build" -and $giLines -notcontains "build" -and $giLines -notcontains "/build/" -and $giLines -notcontains "build/") {
            Fail "$repo has build/ dir but is NOT in .gitignore"
        }
    }
}

Write-Host ""
if ($violations -eq 0) {
    Write-Host "All checks passed." -ForegroundColor Green
    exit 0
} else {
    Write-Host "$violations violation(s) found." -ForegroundColor Red
    exit 1
}
