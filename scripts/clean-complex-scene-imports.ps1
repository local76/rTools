# Post-process the 3 complex scene state.rs / render.rs files to clean up
# the merged sub-module artifacts:
#   - Remove lines like `mod core;`, `mod expansion;`, `mod collapse;`, `mod bird;`
#   - Remove `use super::*;` lines (the super::* is now meaningless)
#   - Remove `use super::super::types::...;` lines (path no longer valid; merge all to `use super::types::...`)
#   - Remove `use super::super::state::...;` etc.
#   - Drop duplicate `use ...` lines
#   - Drop duplicate `use` lines for crate-level items (Duration, get_system_info, etc.)

param([string]$Root = 'C:\Users\jeryd\Synology\Home\Projects\local76\library\src\role\application\scenes')

$ErrorActionPreference = "Stop"

$complexScenes = 'chaos','cosmos','storm'

foreach ($s in $complexScenes) {
    $dir = Join-Path $Root $s
    Write-Host "=== $s ===" -ForegroundColor Cyan
    foreach ($f in 'state.rs','render.rs') {
        $p = Join-Path $dir $f
        if (-not (Test-Path $p)) { continue }
        $c = Get-Content -LiteralPath $p -Raw
        $before = $c

        # Remove `mod xxx;` declarations
        $c = [regex]::Replace($c, '(?m)^\s*mod\s+[a-zA-Z_][a-zA-Z0-9_]*\s*;\s*\r?\n', '')

        # Remove `use super::*;` and `use super::super::*;` lines
        $c = [regex]::Replace($c, '(?m)^\s*use\s+super(?:::\s*super)?::\*\s*;\s*\r?\n', '')

        # Rewrite `use super::super::types::X;` to `use super::types::X;` (and similar for state)
        $c = [regex]::Replace($c, '\buse\s+super::super::(types|state|render)::', 'use super::$1::')

        # Collapse `self::X::` to `X::` (the file is now at the top level)
        $c = [regex]::Replace($c, '\buse\s+self::', 'use ')

        # Deduplicate identical use lines
        $lines = $c -split "`n"
        $seen = @{}
        $deduped = foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ($trimmed -match '^\s*use\s+') {
                if ($seen.ContainsKey($trimmed)) { continue }
                $seen[$trimmed] = $true
            }
            $line
        }
        $c = ($deduped -join "`n")

        if ($c -ne $before) {
            Set-Content -LiteralPath $p -Value $c -NoNewline
            Write-Host "  cleaned $f"
        }
    }
}
