# Flatten the 3 complex scenes (chaos, cosmos, storm) by inlining the
# sub-module methods into the parent impl block.
# Smarter v2: close the first `impl <StructName> {` block, insert the
# sub-module methods as a NEW `impl <StructName> { ... }` block, then leave
# any subsequent impl blocks (e.g. `impl Screensaver`) intact.

param([string]$Root = 'C:\Users\jeryd\Synology\Home\Projects\local76\library\src\role\application\scenes',
      [string]$Temp = 'C:\Users\jeryd\AppData\Local\Temp\opencode\complex-scenes')

$ErrorActionPreference = "Stop"

function Flatten-Complex {
    param(
        [string]$Scene,
        [string]$NewStruct,
        [string]$OldStruct,
        [string]$ParentFile,
        [string[]]$SubFiles,
        [string[]]$RenderFiles
    )

    $dir = Join-Path $Root $Scene
    Write-Host "=== $Scene : $OldStruct -> $NewStruct ===" -ForegroundColor Cyan

    # Read parent
    $parent = Get-Content -LiteralPath $ParentFile -Raw
    $parent = [regex]::Replace($parent, '(?m)^\s*(pub(\([^)]*\))?\s+)?mod\s+\w+\s*;\s*\r?\n', '')
    $parent = [regex]::Replace($parent, '(?m)^\s*use\s+super(?:::\*)?\s*;\s*\r?\n', '')
    $parent = [regex]::Replace($parent, '(?m)^\s*use\s+super::super::types::\{[^}]+\}\s*;\s*\r?\n', '')

    # Read sub-modules and extract method bodies (or whole free functions for cosmos)
    $methodBodies = New-Object System.Collections.Generic.List[string]
    foreach ($sf in $SubFiles) {
        $sub = Get-Content -LiteralPath $sf -Raw
        $sub = [regex]::Replace($sub, '(?m)^\s*use\s+super::(?:super::)?\*\s*;\s*\r?\n', '')
        $sub = [regex]::Replace($sub, "(?m)^\s*use\s+super::$OldStruct\s*;\s*\r?\n", '')
        $sub = [regex]::Replace($sub, '(?m)^\s*use\s+super::super::types::\{[^}]+\}\s*;\s*\r?\n', '')

        # Find `impl <StructName> { ... }` block
        $pattern = "(?ms)\bimpl\s+$OldStruct\s*\{"
        $m = [regex]::Match($sub, $pattern)
        if ($m.Success) {
            $start = $m.Index + $m.Length
            $depth = 1
            $i = $start
            while ($i -lt $sub.Length -and $depth -gt 0) {
                $c = $sub[$i]
                if ($c -eq '{') { $depth++ }
                elseif ($c -eq '}') { $depth-- }
                $i++
            }
            $body = $sub.Substring($start, $i - $start - 1)
            $methodBodies.Add("impl $NewStruct {`n" + $body.Trim() + "`n}")
        } else {
            # No impl block — likely free functions. Take everything after the
            # last `use` line.
            $subLines = $sub -split "`n"
            $lastUse = -1
            for ($j = 0; $j -lt $subLines.Count; $j++) {
                if ($subLines[$j] -match '^\s*use\s+') { $lastUse = $j }
            }
            if ($lastUse -ge 0 -and $lastUse -lt $subLines.Count - 1) {
                $rest = $subLines[($lastUse+1)..($subLines.Count-1)] -join "`n"
                $methodBodies.Add($rest.Trim())
            }
        }
    }

    # Find FIRST `impl <StructName> { ... }` in parent. Split parent into
    # three parts: before-block, the-block-itself, after-block.
    $pattern = "(?ms)\bimpl\s+$OldStruct\s*\{"
    $m = [regex]::Match($parent, $pattern)
    if (-not $m.Success) {
        Write-Warning "  no impl $OldStruct in $Scene parent"
        return
    }
    $start = $m.Index + $m.Length
    $depth = 1
    $i = $start
    while ($i -lt $parent.Length -and $depth -gt 0) {
        $c = $parent[$i]
        if ($c -eq '{') { $depth++ }
        elseif ($c -eq '}') { $depth-- }
        $i++
    }
    $closePos = $i - 1
    $body = $parent.Substring($start, $closePos - $start)

    # Rename struct in body
    $body = [regex]::Replace($body, "\b$OldStruct\b", $NewStruct)
    $before = $parent.Substring(0, $start)
    $before = [regex]::Replace($before, "\b$OldStruct\b", $NewStruct)
    $after = $parent.Substring($closePos + 1)
    $after = [regex]::Replace($after, "\b$OldStruct\b", $NewStruct)

    # Close the first impl, then start a NEW impl block with the appended
    # methods, then continue with after (which contains `impl Screensaver` and
    # any other top-level impl blocks).
    $newAppendedBlock = "}`n`n" + ($methodBodies -join "`n`n")
    $stateContent = $before + $body + $newAppendedBlock + $after
    $stateContent = $stateContent.Replace('super::drawing::', 'super::render::')

    # Build render
    $renderParts = @()
    foreach ($rf in $RenderFiles) {
        $r = Get-Content -LiteralPath $rf -Raw
        $r = [regex]::Replace($r, "\b$OldStruct\b", $NewStruct)
        $r = $r.Replace('super::drawing::', 'super::render::')
        $r = $r.Replace('super::update::',  'super::state::')
        $r = $r.Replace('use super::*;',    '')
        $r = $r.Replace("mod draw_particles;", '')
        $renderParts += $r.TrimEnd() + "`n"
    }
    $renderContent = ($renderParts -join "`n").TrimEnd() + "`n"

    $newMod = "mod render;`nmod state;`nmod types;`n`npub use state::$NewStruct;"

    Set-Content -LiteralPath (Join-Path $dir 'mod.rs')    -Value $newMod        -NoNewline
    Set-Content -LiteralPath (Join-Path $dir 'state.rs')  -Value $stateContent  -NoNewline
    Set-Content -LiteralPath (Join-Path $dir 'render.rs') -Value $renderContent -NoNewline
    Copy-Item -LiteralPath (Join-Path $Temp "$Scene\types.rs") -Destination (Join-Path $dir 'types.rs') -Force

    foreach ($sd in 'update','drawing') {
        $p = Join-Path $dir $sd
        if (Test-Path $p) { Remove-Item -LiteralPath $p -Recurse -Force }
    }
    Write-Host "  done" -ForegroundColor Green
}

Flatten-Complex `
    -Scene 'chaos' `
    -NewStruct 'Chaos' `
    -OldStruct 'Unstable' `
    -ParentFile "$Temp\chaos\update-mod.rs" `
    -SubFiles @("$Temp\chaos\update-core.rs") `
    -RenderFiles @("$Temp\chaos\drawing.rs")

Flatten-Complex `
    -Scene 'cosmos' `
    -NewStruct 'Cosmos' `
    -OldStruct 'LifeEffect' `
    -ParentFile "$Temp\cosmos\update-mod.rs" `
    -SubFiles @(
        "$Temp\cosmos\update-core.rs",
        "$Temp\cosmos\update-expansion.rs",
        "$Temp\cosmos\update-collapse.rs",
        "$Temp\cosmos\update-accretion_helpers.rs"
    ) `
    -RenderFiles @(
        "$Temp\cosmos\drawing-mod.rs",
        "$Temp\cosmos\drawing-draw_particles.rs"
    )

Flatten-Complex `
    -Scene 'storm' `
    -NewStruct 'Storm' `
    -OldStruct 'Pour' `
    -ParentFile "$Temp\storm\update-mod.rs" `
    -SubFiles @(
        "$Temp\storm\update-core.rs",
        "$Temp\storm\update-bird.rs",
        "$Temp\storm\update-lightning.rs",
        "$Temp\storm\update-scenery_and_animals.rs"
    ) `
    -RenderFiles @("$Temp\storm\drawing.rs")
