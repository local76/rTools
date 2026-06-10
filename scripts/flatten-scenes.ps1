# Flatten the 7 simple scenes to a 4-file mod/types/state/render layout.
# Each scene currently has: mod.rs, types.rs, update.rs, drawing.rs
# Target layout:                mod.rs, types.rs, state.rs, render.rs
# Also rename 9 misnamed structs (only 6 of these 7 need it; beams stays "Beams").

param([string]$Root = 'C:\Users\jeryd\Synology\Home\Projects\local76\library\src\role\application\scenes')

$ErrorActionPreference = "Stop"

# Map: scene name -> new struct name (TitleCase matching the scene)
$sceneToStruct = @{
    beams  = 'Beams'           # no change
    bounce = 'Bounce'         # was BhopDashboard
    bursts = 'Bursts'         # was Fireworks
    disco  = 'Disco'          # was Party
    flame  = 'Flame'          # was FireEffect
    glyphs = 'Glyphs'         # was Matrix
    gnats  = 'Gnats'          # was Fireflies
}

# For each scene, identify the OLD struct name that appears in update.rs
# (we need to rename it to the new one)
$oldStruct = @{
    beams  = 'Beams'
    bounce = 'BhopDashboard'
    bursts = 'Fireworks'
    disco  = 'Party'
    flame  = 'FireEffect'
    glyphs = 'Matrix'
    gnats  = 'Fireflies'
}

foreach ($s in $sceneToStruct.Keys) {
    $newStruct = $sceneToStruct[$s]
    $oldName   = $oldStruct[$s]
    $dir       = Join-Path $Root $s
    Write-Host "=== $s : $oldName -> $newStruct ===" -ForegroundColor Cyan

    # Read existing files
    $mod     = Get-Content -LiteralPath (Join-Path $dir 'mod.rs') -Raw
    $types   = Get-Content -LiteralPath (Join-Path $dir 'types.rs') -Raw
    $update  = Get-Content -LiteralPath (Join-Path $dir 'update.rs') -Raw
    $drawing = Get-Content -LiteralPath (Join-Path $dir 'drawing.rs') -Raw

    # 1. Build the new mod.rs (uniform across all 7, alphabetical mod decls,
    #    re-export the new struct name plus any re-exports the old mod.rs had).
    $extras = @()
    foreach ($line in ($mod -split "`n")) {
        if ($line -match '^\s*pub use\s+types::\{([^}]+)\}\s*;?\s*$') {
            $extras += "pub use types::$($Matches[1]);"
        }
    }
    $newMod = "mod render;`nmod state;`nmod types;`n`npub use state::$newStruct;"
    if ($extras) {
        $newMod += "`n" + ($extras -join "`n")
    }

    # 2. State.rs = update.rs with struct rename. Only rename whole-word
    #    occurrences of the old struct name.
    $state = $update
    if ($newStruct -ne $oldName) {
        # Word-boundary regex, case-sensitive
        $state = [regex]::Replace($state, "\b$([regex]::Escape($oldName))\b", $newStruct)
    }

    # 3. Render.rs = drawing.rs with struct rename (same logic). Also
    #    update the `impl <Struct>` block if it exists.
    $render = $drawing
    if ($newStruct -ne $oldName) {
        $render = [regex]::Replace($render, "\b$([regex]::Escape($oldName))\b", $newStruct)
    }

    # 4. types.rs is unchanged.

    # Write the new files (mod, types, state, render). Use new file names.
    Set-Content -LiteralPath (Join-Path $dir 'mod.rs')     -Value $newMod   -NoNewline
    Set-Content -LiteralPath (Join-Path $dir 'state.rs')   -Value $state    -NoNewline
    Set-Content -LiteralPath (Join-Path $dir 'render.rs')  -Value $render   -NoNewline
    # types.rs is the same file path; we don't move it.

    # Delete the old update.rs and drawing.rs.
    Remove-Item -LiteralPath (Join-Path $dir 'update.rs')  -Force
    Remove-Item -LiteralPath (Join-Path $dir 'drawing.rs') -Force

    # Verify final layout
    $finalFiles = Get-ChildItem -LiteralPath $dir -File | Select-Object -ExpandProperty Name
    Write-Host "  final: $($finalFiles -join ', ')" -ForegroundColor Green
}
