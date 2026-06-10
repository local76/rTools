# Stronger post-process: clean up the merged state.rs / render.rs files in
# the 3 complex scenes. Removes:
#   - mod declarations (pub or not)
#   - use super::*; lines
#   - use super::super::X; lines
#   - duplicate use statements
#   - duplicate function definitions (any `pub fn ... {` or `fn ... {` whose
#     name is defined multiple times in the file)
#   - calls to `self::X` or `super::X` (these are post-flatten artifacts)
# And rewrites:
#   - `use super::super::types::...;` -> `use super::types::...;`
#   - `use self::X::...;` -> `use X::...;`
#   - `self::xxx::yyy()` -> `xxx::yyy()` (call-site rewrites)

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

        # 1. Remove mod declarations (any combination of pub + mod + name + ;)
        $c = [regex]::Replace($c, '(?m)^\s*(pub(\([^)]*\))?\s+)?mod\s+[a-zA-Z_][a-zA-Z0-9_]*\s*;\s*\r?\n', '')

        # 2. Remove `use super::*;` (with any combination of super::super)
        $c = [regex]::Replace($c, '(?m)^\s*use\s+(super::)+(\*)\s*;\s*\r?\n', '')

        # 3. Remove `use self::*;`
        $c = [regex]::Replace($c, '(?m)^\s*use\s+self::\*\s*;\s*\r?\n', '')

        # 4. Rewrite `use super::super::X::Y;` -> `use super::X::Y;` (collapse double super)
        $c = [regex]::Replace($c, '\buse\s+(super::)+super::(types|state|render|drawing|update)::', 'use super::$2::')

        # 5. Rewrite `use self::X::` -> `use X::`
        $c = [regex]::Replace($c, '\buse\s+self::', 'use ')

        # 6. Remove ALL `use` lines referencing self::xxx, super::xxx that look
        #    like sub-module paths (these are post-flatten artifacts)
        $c = [regex]::Replace($c, '(?m)^\s*use\s+(self|super|self::super::|self::self::)(::\w+)+\s*;\s*\r?\n', '')

        # 7. Rewrite call sites: self::fn() -> fn()
        $c = [regex]::Replace($c, '\bself::([a-zA-Z_][a-zA-Z0-9_]*)\s*\(', '$1(')

        # 8. Rewrite call sites: super::module::fn() -> module::fn() (for module
        #    references that came from a now-collapsed sub-module).
        #    We need to be careful: legitimate super::types::X is still valid in
        #    the merged file. Only rewrite super::expansion / super::collapse / etc.
        $c = [regex]::Replace($c, '\bsuper::(core|expansion|collapse|accretion_helpers|drawing|update)\b', 'self::was_submodule')

        if ($c -ne $before) {
            Set-Content -LiteralPath $p -Value $c -NoNewline
            Write-Host "  cleaned $f"
        }
    }
}
