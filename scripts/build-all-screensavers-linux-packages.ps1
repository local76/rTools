$ErrorActionPreference = "Stop"

# Builds DEB and RPM packages for all 10 screensavers, cloning each
# screensavers-<scene> repo from github.com/local76 into a local cache.
# Output goes to <repo-cache>/dist/packages/.

$repoCache = $env:SCREENSAVERS_REPO_CACHE
if (-not $repoCache) {
    $repoCache = Join-Path $PSScriptRoot "..\..\.cache\screensavers"
    $repoCache = (Resolve-Path -LiteralPath (Split-Path $repoCache -Parent) -ErrorAction SilentlyContinue).Path
    if (-not $repoCache) {
        $repoCache = "$PSScriptRoot\..\..\.cache\screensavers"
    }
}
$repoCache = (Resolve-Path -LiteralPath $repoCache -ErrorAction SilentlyContinue).Path
if (-not $repoCache) {
    $repoCache = "$PSScriptRoot\..\..\.cache\screensavers"
}

if (-not (Test-Path -LiteralPath $repoCache)) {
    New-Item -ItemType Directory -Path $repoCache -Force | Out-Null
}

$outputDir = Join-Path $repoCache "dist\packages"
if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$screensavers = @('beams', 'bounce', 'flame', 'gnats', 'bursts', 'cosmos', 'glyphs', 'disco', 'storm', 'chaos')

function Get-RepoDir([string]$saver) {
    $dir = Join-Path $repoCache "screensavers-$saver"
    if (-not (Test-Path -LiteralPath "$dir\.git")) {
        if (Test-Path -LiteralPath $dir) {
            Remove-Item -LiteralPath $dir -Recurse -Force
        }
        git clone "https://github.com/local76/screensavers-$saver.git" "$dir"
    }
    return $dir
}

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Building All Linux Packages (DEB & RPM) via Cargo Tools" -ForegroundColor Green
Write-Host "Cache: $repoCache" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

Write-Host ""
Write-Host "1. Building DEB Packages..." -ForegroundColor Cyan
foreach ($saver in $screensavers) {
    Write-Host "-> Building DEB for $saver..." -ForegroundColor Gray
    $dir = Get-RepoDir $saver
    Push-Location $dir
    try {
        cargo deb -o "$outputDir"
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "2. Building RPM Packages..." -ForegroundColor Cyan
foreach ($saver in $screensavers) {
    Write-Host "-> Building RPM for $saver..." -ForegroundColor Gray
    $dir = Get-RepoDir $saver
    Push-Location $dir
    try {
        cargo generate-rpm -o "$outputDir"
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Linux packaging build complete!" -ForegroundColor Green
Write-Host "Packages in: $outputDir" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
