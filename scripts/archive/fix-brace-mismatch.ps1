# Fix the pre-existing brace-mismatch bug in the 3 complex scenes at HEAD.
# The user's commit 9b8484c left these files with `impl Screensaver for <Struct>`
# nested inside `impl <Struct>`. We need to close the outer `impl <Struct>`
# block just before the `impl Screensaver` line.

param([string]$Root = 'C:\Users\jeryd\Synology\Home\Projects\local76\library\src\role\application\scenes')

$ErrorActionPreference = "Stop"

$scenes = 'chaos','cosmos','storm'

foreach ($s in $scenes) {
    $stateFile = Join-Path $Root "$s\state.rs"
    if (-not (Test-Path $stateFile)) { continue }
    Write-Host "=== $s/state.rs ===" -ForegroundColor Cyan
    $c = Get-Content -LiteralPath $stateFile -Raw

    # Verify there's a `impl Screensaver for X {` line that we need to close before
    $hasScreensaverImpl = $c -match 'impl Screensaver for \w+ \{'
    if (-not $hasScreensaverImpl) { Write-Host "  no Screensaver impl"; continue }

    # Verify there's an `impl X {` (non-Screensaver) before it
    $structImplMatch = [regex]::Match($c, '(?m)^impl\s+(\w+)\s*\{')
    if (-not $structImplMatch.Success) { Write-Host "  no struct impl"; continue }
    $structName = $structImplMatch.Groups[1].Value

    # Count braces. With the bug, opening = closing + 1. The closing brace
    # needs to be inserted right before the `impl Screensaver` line.
    $opens = ($c -split '\{' | Measure-Object).Count - 1
    $closes = ($c -split '\}' | Measure-Object).Count - 1
    $diff = $opens - $closes
    Write-Host ("  {0}: {1} open, {2} close, diff={3}" -f $structName, $opens, $closes, $diff)

    if ($diff -eq 0) {
        Write-Host "  already balanced"
        continue
    }

    # Insert $diff closing braces before the `impl Screensaver for X {` line.
    # Use indentation of 0 (close at column 0) for the outermost brace.
    $closer = "`r`n" + ("}" * $diff) + "`r`n`r`n"

    $c = $c -replace '(?m)^(impl Screensaver for )', ($closer + '$1')

    Set-Content -LiteralPath $stateFile -Value $c -NoNewline
    Write-Host "  inserted $diff closing brace(s) before Screensaver impl"
}
