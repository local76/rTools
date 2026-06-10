# Re-encode each scene's icon.ico: convert all 4 PNG entries to 32bpp BMP DIB.
# rc.exe (Windows SDK) mis-handles PNG-compressed entries, so a BMP-only ICO is
# the documented workaround.

param([string]$MonorepoRoot = 'C:\Users\jeryd\Synology\Home\Projects\local76')
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$scenes = 'beams','bounce','bursts','chaos','cosmos','disco','flame','glyphs','gnats','storm'
$work = 'C:\Users\jeryd\AppData\Local\Temp\opencode\ico-rewrite'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Path $work | Out-Null

function Png-To-BmpDib {
    param([byte[]]$PngBytes, [int]$ExpectedSize)
    $tmp = [System.IO.Path]::GetTempFileName() + '.png'
    [System.IO.File]::WriteAllBytes($tmp, $PngBytes)
    $img = [System.Drawing.Image]::FromFile($tmp)
    $bmp = New-Object System.Drawing.Bitmap $ExpectedSize, $ExpectedSize, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.DrawImage($img, 0, 0, $ExpectedSize, $ExpectedSize)
    $g.Dispose()
    $img.Dispose()

    $rect = New-Object System.Drawing.Rectangle 0, 0, $ExpectedSize, $ExpectedSize
    $bd = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $bd.Stride
    $pixelBytes = New-Object byte[] ($stride * $ExpectedSize)
    [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $pixelBytes, 0, $stride * $ExpectedSize)
    $bmp.UnlockBits($bd)
    $bmp.Dispose()
    Remove-Item $tmp -ErrorAction SilentlyContinue

    # Build BITMAPINFOHEADER + pixels + AND mask
    $out = New-Object System.Collections.Generic.List[byte]
    $ih = New-Object byte[] 40
    [BitConverter]::GetBytes([uint32]40).CopyTo($ih, 0)
    [BitConverter]::GetBytes([int32]$ExpectedSize).CopyTo($ih, 4)
    [BitConverter]::GetBytes([int32]($ExpectedSize * 2)).CopyTo($ih, 8)
    [BitConverter]::GetBytes([uint16]1).CopyTo($ih, 12)
    [BitConverter]::GetBytes([uint16]32).CopyTo($ih, 14)
    $out.AddRange($ih)
    $out.AddRange($pixelBytes)
    $andMask = New-Object byte[] ($stride * $ExpectedSize)
    $out.AddRange($andMask)
    , $out.ToArray()
}

function Reencode-Ico {
    param([string]$IcoPath, [string]$OutPath)

    $src = [System.IO.File]::ReadAllBytes($IcoPath)
    $count = [BitConverter]::ToUInt16($src, 4)

    # Extract (size, pngData) pairs in source order
    $entries = New-Object System.Collections.Generic.List[object]
    $p = 6
    for ($i = 0; $i -lt $count; $i++) {
        $w = if ($src[$p] -eq 0) { 256 } else { [int]$src[$p] }
        $sz = [BitConverter]::ToUInt32($src, $p+8)
        $off = [BitConverter]::ToUInt32($src, $p+12)
        $data = $src[$off..($off+$sz-1)]
        $entries.Add([PSCustomObject]@{ Size=$w; PngData=$data })
        $p += 16
    }

    # Convert each PNG to BMP DIB
    $bmpBlobs = @()
    foreach ($e in $entries) {
        $bmp = Png-To-BmpDib -PngBytes $e.PngData -ExpectedSize $e.Size
        $bmpBlobs += ,$bmp
    }

    # Build the new ICO
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter $ms
    $bw.Write([uint16]0)
    $bw.Write([uint16]1)
    $bw.Write([uint16]$count)

    $dataStart = 6 + ($count * 16)
    $cursor = $dataStart
    $offsets = @()
    foreach ($blob in $bmpBlobs) {
        $offsets += $cursor
        $cursor += $blob.Length
    }

    for ($i = 0; $i -lt $count; $i++) {
        $sz = $bmpBlobs[$i].Length
        $w = $entries[$i].Size
        $wByte = if ($w -eq 256) { 0 } else { $w }
        $bw.Write([byte]$wByte)
        $bw.Write([byte]$wByte)
        $bw.Write([byte]0)
        $bw.Write([byte]0)
        $bw.Write([uint16]1)
        $bw.Write([uint16]32)
        $bw.Write([uint32]$sz)
        $bw.Write([uint32]$offsets[$i])
    }

    foreach ($blob in $bmpBlobs) { $bw.Write([byte[]]$blob) }

    $bw.Flush()
    [System.IO.File]::WriteAllBytes($OutPath, $ms.ToArray())
    $bw.Close(); $ms.Close()
}

$results = @()
foreach ($s in $scenes) {
    $ico = Join-Path $MonorepoRoot "screensavers-$s\assets\scene-$s.ico"
    if (-not (Test-Path $ico)) {
        # Fallback to old path
        $ico = Join-Path $MonorepoRoot "screensavers\src\effects\$s\assets\icon.ico"
    }
    $out = Join-Path $work "$s.ico"
    Reencode-Ico -IcoPath $ico -OutPath $out
    $results += [PSCustomObject]@{Scene=$s; SourceSize=(Get-Item $ico).Length; NewSize=(Get-Item $out).Length}
}

"`n--- Re-encoded ICO sizes ---"
$results | Format-Table -AutoSize

"`n--- Verify chaos.ico ICONDIR ---"
$path = Join-Path $work "chaos.ico"
$bytes = [System.IO.File]::ReadAllBytes($path)
$count = [BitConverter]::ToUInt16($bytes, 4)
"chaos.ico ICONDIR count = $count"
$p = 6
for ($i = 0; $i -lt $count; $i++) {
    $b = $p
    $w = if ($bytes[$b] -eq 0) { 256 } else { $bytes[$b] }
    $h = if ($bytes[$b+1] -eq 0) { 256 } else { $bytes[$b+1] }
    $bpp = [BitConverter]::ToUInt16($bytes, $b+6)
    $sz = [BitConverter]::ToUInt32($bytes, $b+8)
    $off = [BitConverter]::ToUInt32($bytes, $b+12)
    $magic = ($bytes[$off..($off+3)] | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
    $kind = if ($bytes[$off] -eq 0x42 -and $bytes[$off+1] -eq 0x4D) { "BMP" } elseif ($bytes[$off] -eq 0x89) { "PNG" } else { "???" }
    "  entry $i : {0,3}x{1,-3} bpp={2,2} size={3,6} offset={4,6} [{5}] {6}" -f $w, $h, $bpp, $sz, $off, $magic, $kind
    $p += 16
}
