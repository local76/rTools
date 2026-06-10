# Final fix for cosmos: recover the 5 update/ sub-module files (deleted by
# 9b8484c) and merge them into state.rs / render.rs at the current HEAD.
# Uses regex-free approach: read the parent, then find the impl <Struct> block,
# then read each sub-file and splice in the function bodies before the closing
# brace of the impl. Also removes the use super::*; and use super::super::*
# lines from the spliced content.

param(
    [string]$Root  = 'C:\Users\jeryd\Synology\Home\Projects\local76\library\src\role\application\scenes',
    [string]$Src   = 'C:\Users\jeryd\AppData\Local\Temp\opencode\cosmos-original'
)

$ErrorActionPreference = "Stop"

# Update files: each is a free-function file, take everything after the use lines
# - update-mod.rs has the impl Screensaver block
# - update-{core,expansion,collapse,accretion_helpers}.rs have free functions
$stateFile = Join-Path $Root 'cosmos\state.rs'
$renderFile = Join-Path $Root 'cosmos\render.rs'

# Read parent
$state = Get-Content -LiteralPath $stateFile -Raw
$render = Get-Content -LiteralPath $renderFile -Raw

# Read each sub-file
$updateMod       = Get-Content -LiteralPath (Join-Path $Src 'update-mod.rs') -Raw
$updateCore      = Get-Content -LiteralPath (Join-Path $Src 'update-core.rs') -Raw
$updateExpansion = Get-Content -LiteralPath (Join-Path $Src 'update-expansion.rs') -Raw
$updateCollapse  = Get-Content -LiteralPath (Join-Path $Src 'update-collapse.rs') -Raw
$updateAccretion = Get-Content -LiteralPath (Join-Path $Src 'update-accretion_helpers.rs') -Raw
$drawingDParticles = Get-Content -LiteralPath (Join-Path $Src 'drawing-draw_particles.rs') -Raw

# Function bodies to inject into state.rs (free functions, take &mut Cosmos)
$freeFunctionBlocks = @($updateCore, $updateExpansion, $updateCollapse, $updateAccretion)

# First strip the broken second use block in state.rs (lines 470+ are duplicates)
# We need to identify and remove the second copy of use statements
$stateLines = $state -split "`n"
$firstImplClose = $null
$secondUseStart = $null
$useCount = 0
for ($i = 0; $i -lt $stateLines.Count; $i++) {
    $line = $stateLines[$i]
    if ($line -match '^\s*use\s+') {
        $useCount++
        if ($useCount -ge 2) {
            # mark the start of the second use block
            if ($secondUseStart -eq $null) { $secondUseStart = $i }
        }
    }
}
# Find the end of the second use block (until a non-use non-blank line)
$secondUseEnd = $null
if ($secondUseStart -ne $null) {
    for ($i = $secondUseStart; $i -lt $stateLines.Count; $i++) {
        $line = $stateLines[$i]
        if ($line -match '^\s*use\s+' -or $line -match '^\s*$') { continue }
        $secondUseEnd = $i
        break
    }
}
Write-Host "  second use block: lines $($secondUseStart+1)..$($secondUseEnd)"
if ($secondUseStart -ne $null -and $secondUseEnd -ne $null) {
    $stateLines = $stateLines[0..($secondUseStart-1)] + $stateLines[$secondUseEnd..($stateLines.Count)]
}

# Now inject the free function bodies (from update/{core,expansion,collapse,accretion_helpers}.rs)
# at the end of state.rs, but ONLY for content that's not already there.
# Actually, simpler approach: take each sub-file, strip its use lines and any
# `mod xxx;` declarations, and append to state.rs.
$injectedBlocks = New-Object System.Collections.Generic.List[string]
foreach ($sub in $freeFunctionBlocks) {
    $cleaned = $sub
    # Remove `use super::super::X;` and `use super::X;` and `use super::*;`
    $cleaned = [regex]::Replace($cleaned, '(?m)^\s*use\s+super::[a-zA-Z0-9_:*\{\},\s]*\s*;\s*\r?\n', '')
    $cleaned = [regex]::Replace($cleaned, '(?m)^\s*use\s+super(?:::\*)?\s*;\s*\r?\n', '')
    # Rewrite the type `LifeEffect` to `Cosmos`
    $cleaned = [regex]::Replace($cleaned, '\bLifeEffect\b', 'Cosmos')
    # Remove mod declarations
    $cleaned = [regex]::Replace($cleaned, '(?m)^\s*(pub\s+)?mod\s+\w+\s*;\s*\r?\n', '')
    $injectedBlocks.Add($cleaned.Trim())
}

# Append all the injected blocks at the end of state.rs (after the impl Screensaver block)
$state = $stateLines -join "`n"
$state = $state.TrimEnd() + "`n`n// -- free functions from update/ sub-modules (preserved from 9b8484c~1) --`n"
foreach ($block in $injectedBlocks) {
    $state += $block + "`n`n"
}

# Now fix state.rs: add the missing types to the use statement
# The current use line: use super::types::{UniverseState, Particle, GravityCenter, LogoPixel};
# We need to also include any types used in the injected blocks (like RgbColor)
# Check what types the injected blocks use
$usedTypes = New-Object System.Collections.Generic.HashSet[string]
foreach ($block in $injectedBlocks) {
    $matches = [regex]::Matches($block, '\b(RgbColor|UniverseState|Particle|GravityCenter|LogoPixel)\b')
    foreach ($m in $matches) { [void]$usedTypes.Add($m.Groups[1].Value) }
}
"`n  types used in injected blocks: $($usedTypes -join ', ')"

# Now fix render.rs: the duplicate use block
# The render.rs has the same problem: a top use block + a second use block from drawing/draw_particles.rs
$renderLines = $render -split "`n"
$useCount = 0
$secondUseStart = $null
for ($i = 0; $i -lt $renderLines.Count; $i++) {
    $line = $renderLines[$i]
    if ($line -match '^\s*use\s+') {
        $useCount++
        if ($useCount -ge 2 -and $secondUseStart -eq $null) {
            $secondUseStart = $i
        }
    }
}
$secondUseEnd = $null
if ($secondUseStart -ne $null) {
    for ($i = $secondUseStart; $i -lt $renderLines.Count; $i++) {
        $line = $renderLines[$i]
        if ($line -match '^\s*use\s+' -or $line -match '^\s*$') { continue }
        $secondUseEnd = $i
        break
    }
}
"`n  render.rs second use block: lines $($secondUseStart+1)..$($secondUseEnd)"
if ($secondUseStart -ne $null -and $secondUseEnd -ne $null) {
    $renderLines = $renderLines[0..($secondUseStart-1)] + $renderLines[$secondUseEnd..($renderLines.Count)]
}
$render = $renderLines -join "`n"

# Append the draw_particles function to render.rs (it has draw_particles_and_trails)
$dpCleaned = $drawingDParticles
$dpCleaned = [regex]::Replace($dpCleaned, '(?m)^\s*use\s+super::[a-zA-Z0-9_:*\{\},\s]*\s*;\s*\r?\n', '')
$dpCleaned = [regex]::Replace($dpCleaned, '(?m)^\s*use\s+super(?:::\*)?\s*;\s*\r?\n', '')
$dpCleaned = [regex]::Replace($dpCleaned, '\bLifeEffect\b', 'Cosmos')
$dpCleaned = [regex]::Replace($dpCleaned, '(?m)^\s*(pub\s+)?mod\s+\w+\s*;\s*\r?\n', '')
$render = $render.TrimEnd() + "`n`n// -- free functions from drawing/ sub-modules --`n" + $dpCleaned + "`n"

# Write
Set-Content -LiteralPath $stateFile  -Value $state  -NoNewline
Set-Content -LiteralPath $renderFile -Value $render -NoNewline

"`n--- state.rs now has $($state.Split("`n").Count) lines, render.rs has $($render.Split("`n").Count) lines"
