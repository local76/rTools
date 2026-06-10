# git_push_all.ps1 — tag + push helper for all 10 local76 repos
#
# Run from the local76/ root. Reads each repo's current version from
# Cargo.toml (or the [workspace] version), creates an annotated
# v<version> tag, and pushes. Idempotent — safe to re-run.
#
# Repos covered:
#   library, screensavers, helm, trance, pulse, ignite,
#   scout, toolkit
#
# (The two umbrella repos apps + toolkit are versioned off their
# README.md "Initial commit" — no Cargo.toml — so this script reads
# their version from the most-recent annotated tag instead.)

$ErrorActionPreference = "Stop"
$local76 = (Resolve-Path "$PSScriptRoot/../..").Path
Write-Host "local76 root: $local76" -ForegroundColor Cyan

$repos = @(
    "library", "screensavers", "helm", "trance", "pulse",
    "ignite", "scout", "toolkit"
)

function Get-Repo-Version {
    param($Path)
    Push-Location $Path
    try {
        # Try Cargo.toml version first (handles both single-crate and
        # workspace layouts, but the apps/toolkit umbrellas don't
        # have a Cargo.toml).
        $candidates = @("Cargo.toml", "crates/*/Cargo.toml")
        foreach ($c in $candidates) {
            $files = Get-ChildItem -Path $c -ErrorAction SilentlyContinue
            foreach ($f in $files) {
                $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
                if ($content -match '(?m)^version\s*=\s*"([^"]+)"') {
                    return $matches[1]
                }
            }
        }
        # Fallback: read the most-recent annotated tag.
        $tag = (git tag -l "v*" --sort=-v:refname | Select-Object -First 1)
        if ($tag) { return $tag.TrimStart("v") }
        throw "Could not determine version for $Path"
    } finally {
        Pop-Location
    }
}

foreach ($repo in $repos) {
    $path = Join-Path $local76 $repo
    if (-not (Test-Path $path)) {
        Write-Host "  SKIP (not a local repo): $repo" -ForegroundColor DarkGray
        continue
    }
    $version = Get-Repo-Version $path
    $tag = "v$version"
    Write-Host "`n[$repo] Tagging $tag..." -ForegroundColor Yellow
    Push-Location $path
    try {
        # Create tag if it doesn't exist
        $existing = git tag -l $tag
        if (-not $existing) {
            git tag -a $tag -m "$repo $version — local76 install-path alignment sprint" | Out-Null
            Write-Host "  Created tag $tag" -ForegroundColor Green
        } else {
            Write-Host "  Tag $tag already exists, skipping" -ForegroundColor DarkGray
        }
        # Push main + tag (idempotent)
        git push origin main --follow-tags
        if ($LASTEXITCODE -ne 0) {
            throw "Push failed for $repo"
        }
        Write-Host "  Pushed $tag" -ForegroundColor Green
    } finally {
        Pop-Location
    }
}

Write-Host "`nAll 8 repos tagged + pushed." -ForegroundColor Green
