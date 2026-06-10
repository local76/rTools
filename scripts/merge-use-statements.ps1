# Final cleanup for the 3 complex scenes: merge multiple
# `use super::types::{A, B, C};` lines into one deduplicated line.
# Also handles `use super::render::X;` / `use super::state::X;` lines.

param([string]$Root = 'C:\Users\jeryd\Synology\Home\Projects\local76\library\src\role\application\scenes')

$ErrorActionPreference = "Stop"

$complexScenes = 'chaos','cosmos','storm'

foreach ($s in $complexScenes) {
    $dir = Join-Path $Root $s
    Write-Host "=== $s ===" -ForegroundColor Cyan
    foreach ($f in 'state.rs','render.rs') {
        $p = Join-Path $dir $f
        if (-not (Test-Path $p)) { continue }
        $orig = Get-Content -LiteralPath $p -Raw

        # Extract all `use PATH::{...};` lines (with brace lists)
        $lineMatches = [regex]::Matches($orig, '(?m)^\s*use\s+([\w:]+)\s*::\s*\{([^}]+)\}\s*;\s*\r?\n')
        if ($lineMatches.Count -eq 0) { continue }

        # Group by path -> set of items
        $byPath = @{}
        foreach ($m in $lineMatches) {
            $path = $m.Groups[1].Value
            $items = $m.Groups[2].Value -split '\s*,\s*' | Where-Object { $_ }
            if (-not $byPath.ContainsKey($path)) { $byPath[$path] = [System.Collections.Generic.HashSet[string]]::new() }
            foreach ($it in $items) { [void]$byPath[$path].Add($it) }
        }

        # Remove all the original `use PATH::{...};` lines
        $c = [regex]::Replace($orig, '(?m)^\s*use\s+[\w:]+::\s*\{[^}]+\}\s*;\s*\r?\n', '')

        # Re-emit one merged line per path, alphabetically sorted
        $newLines = foreach ($path in ($byPath.Keys | Sort-Object)) {
            $items = $byPath[$path] | Sort-Object
            "use $path::{ $($items -join ', ') };"
        }
        # Find the first non-`use`, non-blank line to insert after
        $splitLines = $c -split "`n"
        $insertAfter = 0
        foreach ($line in $splitLines) {
            if ($line -match '^\s*use\s+' -or $line -match '^\s*$') {
                $insertAfter++
            } else { break }
        }
        $beforeArr = @()
        $afterArr  = @()
        for ($i = 0; $i -lt $splitLines.Count; $i++) {
            if ($i -lt $insertAfter) { $beforeArr += $splitLines[$i] }
            else { $afterArr += $splitLines[$i] }
        }
        $before = $beforeArr -join "`n"
        $after  = $afterArr  -join "`n"
        $c = $before + "`n" + ($newLines -join "`n") + "`n" + $after

        if ($c -ne $orig) {
            Set-Content -LiteralPath $p -Value $c -NoNewline
            Write-Host "  merged $($lineMatches.Count) use lines into $((@($newLines)).Count) in $f"
        }
    }
}
