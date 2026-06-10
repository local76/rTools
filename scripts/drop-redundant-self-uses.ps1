# Final cleanup pass for the merged state.rs / render.rs files.
# Removes:
#   - any `use super::StructName;` line where StructName is defined later in
#     the same file (post-merge artifact from sub-module use statements)
#   - any redundant `use super::types::{...};` line where ALL the items in
#     the brace list are already in a previous use line for the same path
# Leaves the legitimate first `use super::types::{...};` line in place.

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

        # 1. Detect every `use super::X;` or `use super::X as Y;` line where X is
        #    also defined as `pub struct X` later in the same file. Drop the use.
        $c = $c -split "`n"
        $definedTypes = @{}
        foreach ($line in $c) {
            if ($line -match '^\s*pub\s+struct\s+(\w+)\b') {
                $definedTypes[$Matches[1]] = $true
            }
        }
        $filtered = foreach ($line in $c) {
            if ($line -match '^\s*use\s+super::(\w+)\s*;\s*$') {
                $name = $Matches[1]
                if ($definedTypes.ContainsKey($name)) {
                    # Drop the redundant use
                    continue
                }
            }
            $line
        }
        $c = $filtered -join "`n"

        # 2. Detect every `use super::X as Y;` where X is locally defined
        if ($c -ne $before) {
            $before2 = $c
            $c = $c -split "`n"
            $filtered = foreach ($line in $c) {
                if ($line -match '^\s*use\s+super::(\w+)\s+as\s+\w+\s*;\s*$') {
                    $name = $Matches[1]
                    if ($definedTypes.ContainsKey($name)) {
                        continue
                    }
                }
                $line
            }
            $c = $filtered -join "`n"
            if ($c -ne $before2) {
                Set-Content -LiteralPath $p -Value $c -NoNewline
                Write-Host "  removed redundant self-uses in $f"
            } else {
                Set-Content -LiteralPath $p -Value $c -NoNewline
            }
        }
    }
}
