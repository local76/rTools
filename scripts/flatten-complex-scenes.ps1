# Flatten the 3 complex scenes (chaos, cosmos, storm) by merging their
# sub-module files into a single state.rs / render.rs at the top level.
# - chaos: merge update/mod.rs + update/core.rs into state.rs; rename drawing.rs -> render.rs
# - cosmos: merge update/{mod,core,expansion,collapse,accretion_helpers}.rs into state.rs;
#           merge drawing/{mod,draw_particles}.rs into render.rs
# - storm: same pattern as cosmos
# All three also rename the public struct to match the scene name.

param([string]$Root = 'C:\Users\jeryd\Synology\Home\Projects\local76\library\src\role\application\scenes')

$ErrorActionPreference = "Stop"

function Flatten-ComplexScene {
    param(
        [string]$Scene,
        [string]$NewStruct,
        [string]$OldStruct,
        [string[]]$UpdateFiles,    # paths to merge into state.rs (in order)
        [string[]]$RenderFiles,    # paths to merge into render.rs (in order)
        [string]$TypesPath         # existing types.rs (no merge needed)
    )

    $dir = Join-Path $Root $Scene
    Write-Host "=== $Scene : $OldStruct -> $NewStruct ===" -ForegroundColor Cyan

    # 1. Read all source files
    $allContent = @{}
    foreach ($f in @($UpdateFiles + $RenderFiles + @($TypesPath))) {
        if (Test-Path $f) {
            $allContent[$f] = Get-Content -LiteralPath $f -Raw
        }
    }

    # 2. Determine the state.rs content
    # Take each update file, strip `use super::*`/`use super::types::*`/`use crate::*` collisions
    # and the outer `mod xxx;` declarations, then concatenate.
    $stateParts = @()
    foreach ($f in $UpdateFiles) {
        if (-not $allContent.ContainsKey($f)) { continue }
        $c = $allContent[$f]
        # Drop leading `mod xxx;` lines that the file might declare
        $c = [regex]::Replace($c, '(?m)^\s*mod\s+\w+\s*;\s*\r?\n', '')
        # Drop the `use super::*` line if present
        $c = [regex]::Replace($c, '(?m)^\s*use\s+super::\*\s*;\s*\r?\n', '')
        $stateParts += $c.TrimEnd() + "`n"
    }
    $state = ($stateParts -join "`n").TrimEnd() + "`n"

    # 3. Determine the render.rs content
    $renderParts = @()
    foreach ($f in $RenderFiles) {
        if (-not $allContent.ContainsKey($f)) { continue }
        $c = $allContent[$f]
        $c = [regex]::Replace($c, '(?m)^\s*mod\s+\w+\s*;\s*\r?\n', '')
        $c = [regex]::Replace($c, '(?m)^\s*use\s+super::\*\s*;\s*\r?\n', '')
        $renderParts += $c.TrimEnd() + "`n"
    }
    $render = ($renderParts -join "`n").TrimEnd() + "`n"

    # 4. Apply the struct rename (word-boundary, case-sensitive)
    if ($NewStruct -ne $OldStruct) {
        $state  = [regex]::Replace($state,  "\b$([regex]::Escape($OldStruct))\b", $NewStruct)
        $render = [regex]::Replace($render, "\b$([regex]::Escape($OldStruct))\b", $NewStruct)
    }

    # 5. Fix cross-references (super::drawing::, super::update::)
    $state  = $state.Replace('super::drawing::', 'super::render::')
    $state  = $state.Replace('super::update::',  'super::state::')
    $render = $render.Replace('super::drawing::', 'super::render::')
    $render = $render.Replace('super::update::',  'super::state::')

    # 6. Build mod.rs (alphabetical, uniform)
    $newMod = "mod render;`nmod state;`nmod types;`n`npub use state::$NewStruct;"

    # 7. Write all 4 files
    Set-Content -LiteralPath (Join-Path $dir 'mod.rs')    -Value $newMod -NoNewline
    Set-Content -LiteralPath (Join-Path $dir 'state.rs')  -Value $state   -NoNewline
    Set-Content -LiteralPath (Join-Path $dir 'render.rs') -Value $render  -NoNewline
    # types.rs is unchanged; already at the right path.

    # 8. Delete the old subdirs and any leftover top-level files
    $oldSubdirs = @('update', 'drawing') | ForEach-Object { Join-Path $dir $_ }
    foreach ($sd in $oldSubdirs) {
        if (Test-Path $sd) {
            Remove-Item -LiteralPath $sd -Recurse -Force
            Write-Host "  removed subdir: $sd"
        }
    }

    # 9. Verify final layout
    $finalFiles = Get-ChildItem -LiteralPath $dir -File | Select-Object -ExpandProperty Name
    Write-Host "  final: $($finalFiles -join ', ')" -ForegroundColor Green
}

# --- chaos ---
# update/mod.rs contains the struct + impl Screensaver + update phase dispatch
# update/core.rs contains the actual update_*_phase methods
# drawing.rs contains the draw_impl
Flatten-ComplexScene `
    -Scene 'chaos' `
    -NewStruct 'Chaos' `
    -OldStruct 'Unstable' `
    -UpdateFiles @(
        "$Root\chaos\update\mod.rs",
        "$Root\chaos\update\core.rs"
    ) `
    -RenderFiles @(
        "$Root\chaos\drawing.rs"
    ) `
    -TypesPath "$Root\chaos\types.rs"

# --- cosmos ---
# update/{mod,core,expansion,collapse,accretion_helpers}.rs + drawing/{mod,draw_particles}.rs
Flatten-ComplexScene `
    -Scene 'cosmos' `
    -NewStruct 'Cosmos' `
    -OldStruct 'LifeEffect' `
    -UpdateFiles @(
        "$Root\cosmos\update\mod.rs",
        "$Root\cosmos\update\core.rs",
        "$Root\cosmos\update\expansion.rs",
        "$Root\cosmos\update\collapse.rs",
        "$Root\cosmos\update\accretion_helpers.rs"
    ) `
    -RenderFiles @(
        "$Root\cosmos\drawing\mod.rs",
        "$Root\cosmos\drawing\draw_particles.rs"
    ) `
    -TypesPath "$Root\cosmos\types.rs"

# --- storm ---
# update/{mod,core,bird,lightning,scenery_and_animals}.rs + drawing.rs
Flatten-ComplexScene `
    -Scene 'storm' `
    -NewStruct 'Storm' `
    -OldStruct 'Pour' `
    -UpdateFiles @(
        "$Root\storm\update\mod.rs",
        "$Root\storm\update\core.rs",
        "$Root\storm\update\bird.rs",
        "$Root\storm\update\lightning.rs",
        "$Root\storm\update\scenery_and_animals.rs"
    ) `
    -RenderFiles @(
        "$Root\storm\drawing.rs"
    ) `
    -TypesPath "$Root\storm\types.rs"
