# Fix cross-references in the 3 complex scene state.rs / render.rs files.
# All sub-module references (`super::super::state`, `super::super::types`, etc.)
# need to be rewritten.

param([string]$Root = 'C:\Users\jeryd\Synology\Home\Projects\local76\library\src\role\application\scenes')

$ErrorActionPreference = "Stop"

$scenes = 'chaos','cosmos','storm'

foreach ($s in $scenes) {
    foreach ($f in 'state.rs','render.rs') {
        $p = Join-Path $Root "$s\$f"
        if (-not (Test-Path $p)) { continue }
        $c = Get-Content -LiteralPath $p -Raw
        $orig = $c

        # `super::super::state::X` -> `super::state::X` (we renamed state.rs in
        # the parent, so super::super::state is now super::state)
        $c = $c.Replace('super::super::state::', 'super::state::')

        # `super::super::types::X` -> `super::types::X`
        $c = $c.Replace('super::super::types::', 'super::types::')

        # `super::super::render::X` -> `super::render::X`
        $c = $c.Replace('super::super::render::', 'super::render::')

        # `self::X` calls where X is a function defined in the same file
        # e.g. self::core::update_life -> update_life
        # (only the cosmos sub-modules used this; core, expansion, collapse,
        # accretion_helpers were sub-module names; they don't exist anymore)
        $c = [regex]::Replace($c, '\bself::(core|expansion|collapse|accretion_helpers|drawing|update)\b', '$1')

        # `mod draw_particles;` no longer exists (was in cosmos drawing/ subdir)
        $c = [regex]::Replace($c, '(?m)^\s*mod\s+(draw_particles|core|expansion|collapse|accretion_helpers|bird|lightning|scenery_and_animals|drawing|update)\s*;\s*\r?\n', '')

        # `use self::draw_particles::X;` -> `use super::X;` (was the cosmos
        # drawing-mod.rs importing from its drawing/draw_particles.rs sub-module;
        # those functions are now in render.rs at the top level)
        $c = $c.Replace('use self::draw_particles::', 'use crate::role::application::scenes::cosmos::render::')

        if ($c -ne $orig) {
            Set-Content -LiteralPath $p -Value $c -NoNewline
            Write-Host "  patched $s/$f"
        }
    }
}
