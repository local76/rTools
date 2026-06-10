# Read each sub-module file, collect all `use` lines and free function bodies.
# Then write a clean cosmos/state.rs and cosmos/render.rs with:
# - A single block of deduplicated use statements
# - The Cosmos struct (from HEAD's state.rs)
# - The free functions from the 4 update/ sub-modules
# - The impl Screensaver for Cosmos
# - The draw_life and draw_particles_and_trails functions (from HEAD's render.rs + the recovered drawing/draw_particles.rs)

param(
    [string]$Root  = 'C:\Users\jeryd\Synology\Home\Projects\local76\library\src\role\application\scenes',
    [string]$Src   = 'C:\Users\jeryd\AppData\Local\Temp\opencode\cosmos-original'
)

$ErrorActionPreference = "Stop"

Push-Location 'C:\Users\jeryd\Synology\Home\Projects\local76\library'
$stateFile = Join-Path $Root 'cosmos\state.rs'
$renderFile = Join-Path $Root 'cosmos\render.rs'

# Read the 5 sub-module files (with the original imports)
$updateMod       = Get-Content -LiteralPath (Join-Path $Src 'update-mod.rs') -Raw
$updateCore      = Get-Content -LiteralPath (Join-Path $Src 'update-core.rs') -Raw
$updateExpansion = Get-Content -LiteralPath (Join-Path $Src 'update-expansion.rs') -Raw
$updateCollapse  = Get-Content -LiteralPath (Join-Path $Src 'update-collapse.rs') -Raw
$updateAccretion = Get-Content -LiteralPath (Join-Path $Src 'update-accretion_helpers.rs') -Raw
$drawingDParticles = Get-Content -LiteralPath (Join-Path $Src 'drawing-draw_particles.rs') -Raw

# Read the struct definition from HEAD
$headState  = & git show HEAD:src/role/application/scenes/cosmos/state.rs
$headRender = & git show HEAD:src/role/application/scenes/cosmos/render.rs
$headTypes  = & git show HEAD:src/role/application/scenes/cosmos/types.rs

# Collect all `use` lines from all 5 sub-modules + the struct + impl, dedup
$allUseLines = New-Object System.Collections.Generic.HashSet[string]
foreach ($src in @($updateMod, $updateCore, $updateExpansion, $updateCollapse, $updateAccretion, $drawingDParticles)) {
    $useMatches = [regex]::Matches($src, '(?m)^\s*use\s+[^;]+;\s*\r?\n')
    foreach ($m in $useMatches) { [void]$allUseLines.Add($m.Value.Trim()) }
}

# Rewrite all `use` lines to point at the merged structure:
#   - `use super::X;` -> `use super::state::X;` (struct/fn is in state.rs)
#   - `use super::super::types::X;` -> `use super::types::X;` (types is in cosmos/types.rs)
#   - `use super::expansion as update_expansion;` -> just keep the fn names directly
#   - Drop `use super::*;` and `mod xxx;` and the like
$mergedUse = New-Object System.Collections.Generic.List[string]
foreach ($u in $allUseLines) {
    $line = $u
    if ($line -match '^\s*use\s+super::\*\s*;') { continue }
    if ($line -match '^\s*use\s+super::expansion\s+as\s+') { continue }
    if ($line -match '^\s*use\s+super::collapse\s+as\s+') { continue }
    # Replace super::super::types:: with super::types::
    $line = $line.Replace('super::super::types::', 'super::types::')
    # Replace super::super::state:: with super::state::
    $line = $line.Replace('super::super::state::', 'super::state::')
    # Replace `use super::X;` (single name) with `use super::state::X;`
    if ($line -match '^\s*use\s+super::([A-Z][a-zA-Z0-9_]*)\s*;') {
        $name = $Matches[1]
        if ($name -notin @('types','render','state','super')) {
            $line = "use super::state::$name;"
        }
    }
    if (-not $mergedUse.Contains($line)) { $mergedUse.Add($line) }
}

"`n--- final use lines ---"
$mergedUse | ForEach-Object { "  $_" }
"`n---"

# Extract the Cosmos struct + impl Default + impl Cosmos blocks from HEAD state.rs
$structMatch = [regex]::Match($headState, '(?ms)^pub struct Cosmos \{[^}]*\}')
$structDef = if ($structMatch.Success) { $structMatch.Value } else { "" }
$defaultImplMatch = [regex]::Match($headState, '(?ms)^impl Default for Cosmos \{[^}]*\}')
$defaultImpl = if ($defaultImplMatch.Success) { $defaultImplMatch.Value } else { "" }
$cosmosImplMatch = [regex]::Match($headState, '(?ms)^impl Cosmos \{(.*?)^\}')
$cosmosImplBody = ""
if ($cosmosImplMatch.Success) {
    # Body is what's inside the impl, between `{` and the matching `}`
    $cosmosImplBody = $cosmosImplMatch.Groups[1].Value
}

# Extract the impl Screensaver for Cosmos block from HEAD state.rs
$screensaverImplMatch = [regex]::Match($headState, '(?ms)^impl Screensaver for Cosmos \{.*?^\}')
$screensaverImpl = if ($screensaverImplMatch.Success) { $screensaverImplMatch.Value } else { "" }

# Extract the draw_life function from HEAD render.rs
$drawLifeMatch = [regex]::Match($headRender, '(?ms)^pub fn draw_life\(.*?^\}')
$drawLife = if ($drawLifeMatch.Success) { $drawLifeMatch.Value } else { "" }

# For the free functions in update/{core,expansion,collapse,accretion_helpers}.rs,
# extract each `pub fn X(...) { ... }` and put it in its own impl block.
# Each sub-file has multiple pub fns. We extract them all.

$freeFns = New-Object System.Collections.Generic.List[string]
foreach ($src in @($updateCore, $updateExpansion, $updateCollapse, $updateAccretion)) {
    # Find all `pub fn` declarations at the top level (indentation = 0 or 4 spaces)
    $fnMatches = [regex]::Matches($src, '(?ms)^pub fn [^{]*\{')
    foreach ($m in $fnMatches) {
        # Find the end of this function (matching braces)
        $start = $m.Index + $m.Length
        $depth = 1
        $i = $start
        while ($i -lt $src.Length -and $depth -gt 0) {
            $c = $src[$i]
            if ($c -eq '{') { $depth++ }
            elseif ($c -eq '}') { $depth-- }
            $i++
        }
        $fnBody = $src.Substring($m.Index, $i - $m.Index)
        $freeFns.Add($fnBody)
    }
}
"`n--- free functions collected: $($freeFns.Count) ---"
foreach ($fn in $freeFns) {
    $name = ([regex]::Match($fn, 'pub fn (\w+)')).Groups[1].Value
    "  $name"
}

# Extract draw_particles_and_trails from drawing/draw_particles.rs
$dptMatch = [regex]::Match($drawingDParticles, '(?ms)^pub fn draw_particles_and_trails\(.*?^\}')
$drawPartFn = if ($dptMatch.Success) { $dptMatch.Value } else { "" }

# Build the new state.rs
$newState = ""
# 1. use statements
foreach ($u in $mergedUse) { $newState += $u + "`n" }
# 2. struct
$newState += "`n" + $structDef + "`n"
# 3. impl Default
$newState += "`n" + $defaultImpl + "`n"
# 4. impl Cosmos (new())
$newState += "`nimpl Cosmos {`n" + $cosmosImplBody + "`n}`n"
# 5. free functions from update/ sub-modules
$newState += "`n// -- free functions from update/ sub-modules (preserved from 9b8484c~1) --`n"
foreach ($fn in $freeFns) { $newState += $fn + "`n`n" }
# 6. impl Screensaver
$newState += $screensaverImpl + "`n"

# Build the new render.rs
$newRender = ""
foreach ($u in $mergedUse) { $newRender += $u + "`n" }
# Replace `use super::state::X;` with `use super::X;` for types in state (Cosmos, etc.)
# But the render.rs needs different things:
#   - Cosmos (the type) is in state.rs
#   - draw_life function takes &Cosmos, &mut grid
#   - draw_particles_and_trails function takes &Cosmos
# The actual draw_life code is the function body from HEAD render.rs
$newRender += "`n" + $drawLife + "`n`n"
$newRender += "// -- draw_particles_and_trails from drawing/ sub-module --`n"
$newRender += $drawPartFn + "`n"

# Make the state and render files use the right type paths
# In state.rs: use statements refer to super::state::Cosmos (for impl), super::types::...
# In render.rs: same plus use crate::core::TerminalCell
# We need to add `use crate::core::TerminalCell;` and `use crate::core::screensaver::Screensaver;`
# to render.rs and adjust use paths.

# Write the files
Set-Content -LiteralPath $stateFile  -Value $newState  -NoNewline
Set-Content -LiteralPath $renderFile -Value $newRender -NoNewline

"--- state.rs: $($newState.Split("`n").Count) lines, render.rs: $($newRender.Split("`n").Count) lines"
Pop-Location
