# Cosmos-specific fix: the sub-modules used super::super::state / super::super::types
# paths which need rewriting after the flatten.

param([string]$Path = 'C:\Users\jeryd\Synology\Home\Projects\local76\library\src\role\application\scenes\cosmos\state.rs')

$ErrorActionPreference = "Stop"
$c = Get-Content -LiteralPath $Path -Raw
$orig = $c

# Replace `self::core::X(...)` calls with `X(...)` (the function is now in this file)
$c = [regex]::Replace($c, '\bself::core::([a-zA-Z_][a-zA-Z0-9_]*)\b', '$1')

# Replace `super::super::state::X` -> `super::X` and `super::super::types::X` -> `super::types::X`
$c = $c.Replace('super::super::state::', 'super::state::')
$c = $c.Replace('super::super::types::', 'super::types::')

# Replace `super::expansion`, `super::collapse`, `super::accretion_helpers` with the actual fn names
# The original code used `use super::expansion as update_expansion;` and then called
# `update_expansion(eff, ...)`. Since the function body is now in this same file, the
# call site should be the plain function name.
# But we kept the `as update_expansion` alias in our merge. So actually those
# calls use the alias names. Let me find them:
$c = $c.Replace('use super::expansion as update_expansion;', '// merged expansion functions follow')
$c = $c.Replace('use super::collapse as update_collapse;',     '// merged collapse functions follow')
# Calls like update_expansion(eff, ...) are fine; the as-alias was the import.

if ($c -ne $orig) {
    Set-Content -LiteralPath $Path -Value $c -NoNewline
    Write-Host "  patched cosmos state.rs"
}
