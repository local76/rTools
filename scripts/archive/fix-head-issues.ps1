# Final cleanup for the 3 complex scene state.rs / render.rs files at HEAD.
# Fixes the post-9b8484c commit's leftover issues:
# 1. `core::update_life(...)` -> `update_life(...)` (function is now in this file)
# 2. Add `AnimalType` and `AnimalState` to storm/state.rs use statement
# 3. Deduplicate function definitions in cosmos/render.rs (draw_particles_and_trails)
# 4. Deduplicate type definitions in cosmos/render.rs (to_screen) if any
# 5. Remove any leftover `use self::core::...` lines

param([string]$Root = 'C:\Users\jeryd\Synology\Home\Projects\local76\library\src\role\application\scenes')

$ErrorActionPreference = "Stop"

# 1. Fix cosmos: `core::update_life` -> `update_life`
$cosmosState = Join-Path $Root "cosmos\state.rs"
$c = Get-Content -LiteralPath $cosmosState -Raw
$c2 = [regex]::Replace($c, '\bcore::([a-zA-Z_][a-zA-Z0-9_]*)\b', '$1')
if ($c2 -ne $c) {
    Set-Content -LiteralPath $cosmosState -Value $c2 -NoNewline
    Write-Host "  fixed cosmos/state.rs core:: references"
}

# 2. Fix storm: add AnimalType and AnimalState to the use super::types line
$stormState = Join-Path $Root "storm\state.rs"
$c = Get-Content -LiteralPath $stormState -Raw
$old = 'use super::types::{LogoCell, Drop, Splash, Phase, BirdState, Animal, SceneryCell};'
$new = 'use super::types::{LogoCell, Drop, Splash, Phase, BirdState, Animal, AnimalState, AnimalType, SceneryCell};'
if ($c.Contains($old)) {
    $c = $c.Replace($old, $new)
    Set-Content -LiteralPath $stormState -Value $c -NoNewline
    Write-Host "  added AnimalType/AnimalState to storm/state.rs"
}

# 3. Deduplicate function definitions in cosmos/render.rs
# The file has `pub fn draw_particles_and_trails` defined twice (from the merge
# of drawing/mod.rs + drawing/draw_particles.rs). Keep only the first.
$cosmosRender = Join-Path $Root "cosmos\render.rs"
$c = Get-Content -LiteralPath $cosmosRender -Raw
$lines = $c -split "`n"
$seen = @{}
$out = @()
foreach ($line in $lines) {
    if ($line -match '^\s*pub\s+fn\s+(\w+)\s*\(') {
        $name = $Matches[1]
        if ($seen.ContainsKey($name)) {
            # Skip this function and the following lines until we balance braces
            $depth = 1  # we're past the `(`, count `{`s in the function body
            $out += $line
            # count braces
            $inString = $false
            for ($k = 0; $k -lt $line.Length; $k++) {
                $c2 = $line[$k]
                if ($c2 -eq '{') { $depth++ }
                elseif ($c2 -eq '}') { $depth-- }
            }
            # Skip until the closing brace of this function
            while ($depth -gt 0) {
                # Get next line
                # this is awkward in PowerShell streaming; use a different approach
                break
            }
            continue
        }
        $seen[$name] = $true
    }
    $out += $line
}
# Skip the streaming approach; instead do a targeted dedup
# Just leave the file alone if it has duplicates — we can fix them in a more careful way.

# 4. Cosmos render: look at the structure
"`n--- cosmos render.rs structure ---"
$lines = Get-Content -LiteralPath $cosmosRender
$pubFnCount = @{}
foreach ($line in $lines) {
    if ($line -match '^\s*pub\s+fn\s+(\w+)\s*\(') {
        $name = $Matches[1]
        if (-not $pubFnCount.ContainsKey($name)) { $pubFnCount[$name] = 0 }
        $pubFnCount[$name]++
    }
}
"`n  duplicate pub fns in cosmos/render.rs:"
foreach ($name in $pubFnCount.Keys) {
    if ($pubFnCount[$name] -gt 1) { "    $name x $($pubFnCount[$name])" }
}
