# verify-icon.ps1 — verify ICONDIR entries in a folder of built Windows binaries
#
# Scans every .exe / .scr in the given directory, locates the ICONDIR
# (00 00 01 00 …) inside the binary, decodes the ICONDIRENTRY rows, and
# reports a PASS / FAIL per binary.
#
# A "pass" means: at least one ICONDIR with >= 4 valid 32-bpp entries at
# 16/32/48/256. That is the contract every local76 binary promises per
# library/docs/VISUAL_STANDARDS.md § B ("the .ico must be a multi-resolution
# Windows ICO containing exactly 16, 32, 48, 256 sizes at 32-bit RGBA").
#
# Recipe: library/docs/ICON_TROUBLESHOOTING.md
#
# Usage:
#   pwsh ./toolkit/scripts/verify-icon.ps1                          # default: dist/binaries
#   pwsh ./toolkit/scripts/verify-icon.ps1 -BinDir path/to/binaries
#   pwsh ./toolkit/scripts/verify-icon.ps1 -Json                    # machine-readable output
#
# Exit codes:
#   0  all binaries passed
#   1  at least one binary failed
#   2  no binaries found in the given directory

param(
    [string]$BinDir = "dist/binaries",
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $BinDir)) {
    Write-Error "BinDir not found: $BinDir"
    exit 2
}

$binaries = Get-ChildItem -LiteralPath $BinDir -File | Where-Object {
    $_.Extension -in @(".exe", ".scr")
}

if (-not $binaries) {
    Write-Warning "No .exe / .scr files found in $BinDir"
    exit 2
}

function Get-BestIconDir {
    param([byte[]]$Bytes)

    $best = $null
    $len = $Bytes.Length
    for ($i = 0; $i -lt $len - 6; $i++) {
        if ($Bytes[$i] -ne 0) { continue }
        if ($Bytes[$i+1] -ne 0) { continue }
        if ($Bytes[$i+2] -ne 1) { continue }
        if ($Bytes[$i+3] -ne 0) { continue }

        $count = [BitConverter]::ToUInt16($Bytes, $i+4)
        if ($count -lt 1 -or $count -gt 16) { continue }

        $p = $i + 6
        $valid32bpp = 0
        $sizes = New-Object System.Collections.Generic.List[string]
        for ($k = 0; $k -lt $count; $k++) {
            if ($p + 16 -gt $len) { break }
            $w = $Bytes[$p]
            $h2 = $Bytes[$p + 1]
            $bpp = [BitConverter]::ToUInt16($Bytes, $p + 6)
            $sz = [BitConverter]::ToUInt32($Bytes, $p + 8)
            $dimW = if ($w -eq 0) { 256 } else { $w }
            $dimH = if ($h2 -eq 0) { 256 } else { $h2 }
            $sizes.Add(("{0}x{1}@{2}bpp" -f $dimW, $dimH, $bpp))
            if ($bpp -eq 32 -and $dimW -in 16, 32, 48, 256 -and $dimH -in 16, 32, 48, 256) {
                $valid32bpp++
            }
            $p += 16
        }
        $candidate = [PSCustomObject]@{
            Offset      = $i
            Count       = $count
            Valid32bpp  = $valid32bpp
            Sizes       = ($sizes -join " ")
        }
        if ($null -eq $best -or $candidate.Valid32bpp -gt $best.Valid32bpp) {
            $best = $candidate
        }
    }
    $best
}

$results = foreach ($bin in $binaries) {
    $bytes = [System.IO.File]::ReadAllBytes($bin.FullName)
    $best  = Get-BestIconDir -Bytes $bytes
    $verdict = if ($best -and $best.Valid32bpp -ge 4) { "PASS" } else { "FAIL" }
    [PSCustomObject]@{
        Binary     = $bin.Name
        Size       = $bytes.Length
        Offset     = if ($best) { $best.Offset } else { "-" }
        Count      = if ($best) { $best.Count } else { 0 }
        Valid32bpp = if ($best) { $best.Valid32bpp } else { 0 }
        Sizes      = if ($best) { $best.Sizes } else { "" }
        Verdict    = $verdict
    }
}

if ($Json) {
    $results | ConvertTo-Json -Depth 3
} else {
    $results | Format-Table -AutoSize
    $fails = @($results | Where-Object { $_.Verdict -eq "FAIL" })
    $pass  = @($results | Where-Object { $_.Verdict -eq "PASS" })
    ""
    Write-Host ("  PASS: {0}" -f $pass.Count) -ForegroundColor Green
    Write-Host ("  FAIL: {0}" -f $fails.Count) -ForegroundColor $(if ($fails.Count -gt 0) { "Red" } else { "Green" })
}

if (@($results | Where-Object { $_.Verdict -eq "FAIL" }).Count -gt 0) { exit 1 } else { exit 0 }
