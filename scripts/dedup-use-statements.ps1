# Dedup use statements in the 3 complex scene state.rs / render.rs files
# at HEAD. The 9b8484c commit's flatten left some files with two copies of
# the same `use super::X;` or `use super::types::{...};` block.

param([string]$Root = 'C:\Users\jeryd\Synology\Home\Projects\local76\library\src\role\application\scenes')

$ErrorActionPreference = "Stop"

$scenes = 'chaos','cosmos','storm'

foreach ($s in $scenes) {
    foreach ($f in 'state.rs','render.rs') {
        $p = Join-Path $Root "$s\$f"
        if (-not (Test-Path $p)) { continue }
        $c = Get-Content -LiteralPath $p -Raw
        $orig = $c
        $lines = $c -split "`n"
        $seen = @{}
        $out = @()
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ($trimmed -match '^\s*use\s+') {
                if ($seen.ContainsKey($trimmed)) {
                    continue
                }
                $seen[$trimmed] = $true
            }
            $out += $line
        }
        $c = $out -join "`n"
        if ($c -ne $orig) {
            Set-Content -LiteralPath $p -Value $c -NoNewline
            $before = ($orig -split "`n").Count
            $after  = ($c -split "`n").Count
            Write-Host "  deduped $s/$f ($before -> $after lines)"
        }
    }
}
