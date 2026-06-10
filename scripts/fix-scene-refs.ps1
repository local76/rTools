# Fix cross-file references in the 7 simple scenes after the flatten:
#   super::drawing::  -> super::render::
#   super::update::   -> super::state::
# Also verify each scene's mod.rs is uniform (mod render; mod state; mod types; order)

param([string]$Root = 'C:\Users\jeryd\Synology\Home\Projects\local76\library\src\role\application\scenes')

$ErrorActionPreference = "Stop"

$scenes = 'beams','bounce','bursts','disco','flame','glyphs','gnats'
foreach ($s in $scenes) {
    $dir = Join-Path $Root $s
    Write-Host "=== $s ===" -ForegroundColor Cyan
    foreach ($f in 'state.rs','render.rs') {
        $p = Join-Path $dir $f
        if (Test-Path $p) {
            $c = Get-Content -LiteralPath $p -Raw
            $before = $c
            $c = $c.Replace('super::drawing::', 'super::render::')
            $c = $c.Replace('super::update::',  'super::state::')
            if ($c -ne $before) {
                Set-Content -LiteralPath $p -Value $c -NoNewline
                Write-Host "  fixed references in $f"
            }
        }
    }
}
