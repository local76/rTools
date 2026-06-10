$ErrorActionPreference = "Stop"

# Builds DEB packages for all 10 screensavers and 5 apps from local monorepo checkouts.
# Output goes to <monorepoRoot>/dist/packages/.

$monorepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$outputDir = Join-Path $monorepoRoot "dist\packages"

if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$screensavers = @('beams', 'bounce', 'flame', 'gnats', 'bursts', 'cosmos', 'glyphs', 'disco', 'storm', 'chaos')
$apps = @('helm', 'pulse', 'scout', 'trance', 'ignite')

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Building All local76 DEB Packages Locally" -ForegroundColor Green
Write-Host "Output Directory: $outputDir" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green

Write-Host ""
Write-Host "1. Building Screensaver DEB Packages in Parallel..." -ForegroundColor Cyan
$screensavers | ForEach-Object -ThrottleLimit 4 -Parallel {
    $saver = $_
    $outputDir = $using:outputDir
    $monorepoRoot = $using:monorepoRoot

    $dir = Join-Path $monorepoRoot "screensavers-$saver"
    if (Test-Path $dir) {
        Write-Host "-> Building DEB for screensavers-$saver..." -ForegroundColor Gray
        $process = Start-Process -FilePath "cargo" -ArgumentList "deb", "-o", $outputDir -WorkingDirectory $dir -NoNewWindow -PassThru -Wait
        if ($process.ExitCode -ne 0) {
            Write-Error "Failed to build DEB package for screensavers-$saver (Exit Code: $($process.ExitCode))"
        } else {
            Write-Host "-> Completed DEB for screensavers-$saver!" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "2. Building Application DEB Packages in Parallel..." -ForegroundColor Cyan
$apps | ForEach-Object -ThrottleLimit 3 -Parallel {
    $app = $_
    $outputDir = $using:outputDir
    $monorepoRoot = $using:monorepoRoot

    $dir = Join-Path $monorepoRoot "app-$app"
    if (-not (Test-Path $dir)) {
        $dir = Join-Path $monorepoRoot $app
    }

    if (Test-Path $dir) {
        Write-Host "-> Building DEB for app-$app..." -ForegroundColor Gray
        $process = Start-Process -FilePath "cargo" -ArgumentList "deb", "-o", $outputDir -WorkingDirectory $dir -NoNewWindow -PassThru -Wait
        if ($process.ExitCode -ne 0) {
            Write-Error "Failed to build DEB package for app-$app (Exit Code: $($process.ExitCode))"
        } else {
            Write-Host "-> Completed DEB for app-$app!" -ForegroundColor Green
        }
    }
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "DEB packaging build complete!" -ForegroundColor Green
Write-Host "Packages in: $outputDir" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
