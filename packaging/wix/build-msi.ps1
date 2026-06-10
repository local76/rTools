param(
    [Parameter(Mandatory=$true)]
    [string]$AppName,
    [Parameter(Mandatory=$true)]
    [string]$AppVersion,
    [Parameter(Mandatory=$true)]
    [string]$ExecutableName, # e.g. "trance.scr" or "pulse.exe"
    [Parameter(Mandatory=$false)]
    [string]$IconPath = "", # Path to .ico file
    [Parameter(Mandatory=$false)]
    [string]$DialogBmp = "", # 493x312 Welcome/Finish image
    [Parameter(Mandatory=$false)]
    [string]$BannerBmp = "", # 493x58 Header banner image
    [Parameter(Mandatory=$false)]
    [switch]$IncludeScreensavers = $false
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$monorepoRoot = Resolve-Path (Join-Path $scriptRoot "..\..\..")

# Resolve WiX toolset paths
$wixDir = $null
foreach ($path in @("C:\Program Files (x86)\WiX Toolset v3.11\bin", "C:\Program Files\WiX Toolset v3.11\bin", "C:\Program Files (x86)\WiX Toolset v3.14\bin")) {
    if (Test-Path $path) {
        $wixDir = $path
        break
    }
}

if (-not $wixDir) {
    # Check if 'candle' is in Path
    if (Get-Command "candle" -ErrorAction SilentlyContinue) {
        $wixDir = ""
    } else {
        throw "WiX Toolset v3.11/v3.14 not found. Please install it from https://wixtoolset.org/ or add it to PATH."
    }
}

Write-Host "Staging build directories..." -ForegroundColor Cyan
$stageDir = Join-Path $scriptRoot "stage"
if (Test-Path $stageDir) { Remove-Item -Recurse -Force $stageDir }
$null = New-Item -ItemType Directory -Path $stageDir -Force

# Copy main binary
$binDir = Join-Path $monorepoRoot "$AppName\target\release"
if (-not (Test-Path $binDir)) {
    $binDir = Join-Path $monorepoRoot "$AppName\target\debug"
}
$srcExe = Join-Path $binDir $ExecutableName
if (-not (Test-Path $srcExe)) {
    throw "Executable not found at $srcExe. Please build the application first."
}
Copy-Item $srcExe (Join-Path $stageDir $ExecutableName)

# Copy screensavers if requested
if ($IncludeScreensavers) {
    $screensStage = Join-Path $stageDir "screensavers"
    $null = New-Item -ItemType Directory -Path $screensStage -Force
    $screensBinDir = Join-Path $monorepoRoot "screensavers\target\release"
    if (-not (Test-Path $screensBinDir)) {
        $screensBinDir = Join-Path $monorepoRoot "screensavers\target\debug"
    }
    
    $effects = @("beams", "bounce", "bursts", "chaos", "cosmos", "disco", "flame", "glyphs", "gnats", "storm")
    foreach ($effect in $effects) {
        $effectExe = Join-Path $screensBinDir "$effect.scr"
        if (-not (Test-Path $effectExe)) {
            $effectExe = Join-Path $screensBinDir "$effect.exe"
        }
        if (Test-Path $effectExe) {
            # Copy and force .scr extension for screensaver shims
            Copy-Item $effectExe (Join-Path $screensStage "$effect.scr")
        } else {
            Write-Warning "Screensaver effect binary '$effect' not found in $screensBinDir. Skipping from payload."
        }
    }
}

# Resolve assets
$iconSrc = $IconPath
if ($iconSrc -and (Test-Path $iconSrc)) {
    Copy-Item $iconSrc (Join-Path $stageDir "app.ico")
} else {
    # Fallback default icon path
    $fallbackIcon = Join-Path $monorepoRoot "$AppName\assets\brand\app.ico"
    if (Test-Path $fallbackIcon) {
        Copy-Item $fallbackIcon (Join-Path $stageDir "app.ico")
    }
}

# Resolve Custom Bitmaps for premium UI look
if ($DialogBmp -and (Test-Path $DialogBmp)) {
    Copy-Item $DialogBmp (Join-Path $stageDir "dialog.bmp")
}
if ($BannerBmp -and (Test-Path $BannerBmp)) {
    Copy-Item $BannerBmp (Join-Path $stageDir "banner.bmp")
}

Write-Host "Generating WiX source file..." -ForegroundColor Cyan
$templatePath = Join-Path $scriptRoot "template.wxs"
$wxsContent = Get-Content $templatePath -Raw

# Replace variables
$wxsContent = $wxsContent.Replace("{{AppName}}", $AppName)
$wxsContent = $wxsContent.Replace("{{AppVersion}}", $AppVersion)
$wxsContent = $wxsContent.Replace("{{ExecutableName}}", $ExecutableName)

# Handle Screensavers Conditional inclusion in WXS
if ($IncludeScreensavers) {
    $wxsContent = $wxsContent.Replace("<!--{{ScreensaversFeature}}-->", @"
      <Feature Id="ScreensaversFeature" Title="Retro Screensaver Effects" Level="1" Description="Installs the 10 custom screensaver shims (beams, bounce, glyphs, cosmos, etc.) directly into your local discovery directory.">
        <ComponentGroupRef Id="ScreensaverBinaries" />
      </Feature>
"@)
    $wxsContent = $wxsContent.Replace("<!--{{ScreensaversComponents}}-->", @"
      <DirectoryRef Id="ScreensaversDir">
        <Component Id="beams.scr" Guid="*">
          <File Id="beams.scr" Source="stage\screensavers\beams.scr" KeyPath="yes" />
        </Component>
        <Component Id="bounce.scr" Guid="*">
          <File Id="bounce.scr" Source="stage\screensavers\bounce.scr" KeyPath="yes" />
        </Component>
        <Component Id="bursts.scr" Guid="*">
          <File Id="bursts.scr" Source="stage\screensavers\bursts.scr" KeyPath="yes" />
        </Component>
        <Component Id="chaos.scr" Guid="*">
          <File Id="chaos.scr" Source="stage\screensavers\chaos.scr" KeyPath="yes" />
        </Component>
        <Component Id="cosmos.scr" Guid="*">
          <File Id="cosmos.scr" Source="stage\screensavers\cosmos.scr" KeyPath="yes" />
        </Component>
        <Component Id="disco.scr" Guid="*">
          <File Id="disco.scr" Source="stage\screensavers\disco.scr" KeyPath="yes" />
        </Component>
        <Component Id="flame.scr" Guid="*">
          <File Id="flame.scr" Source="stage\screensavers\flame.scr" KeyPath="yes" />
        </Component>
        <Component Id="glyphs.scr" Guid="*">
          <File Id="glyphs.scr" Source="stage\screensavers\glyphs.scr" KeyPath="yes" />
        </Component>
        <Component Id="gnats.scr" Guid="*">
          <File Id="gnats.scr" Source="stage\screensavers\gnats.scr" KeyPath="yes" />
        </Component>
        <Component Id="storm.scr" Guid="*">
          <File Id="storm.scr" Source="stage\screensavers\storm.scr" KeyPath="yes" />
        </Component>
      </DirectoryRef>
"@)
} else {
    $wxsContent = $wxsContent.Replace("<!--{{ScreensaversFeature}}-->", "")
    $wxsContent = $wxsContent.Replace("<!--{{ScreensaversComponents}}-->", "")
}

# Branding graphics customization flags
if (Test-Path (Join-Path $stageDir "dialog.bmp")) {
    $wxsContent = $wxsContent.Replace("<!--{{DialogBmp}}-->", '<WixVariable Id="WixUIDialogBmp" Value="stage\dialog.bmp" />')
} else {
    $wxsContent = $wxsContent.Replace("<!--{{DialogBmp}}-->", "")
}
if (Test-Path (Join-Path $stageDir "banner.bmp")) {
    $wxsContent = $wxsContent.Replace("<!--{{BannerBmp}}-->", '<WixVariable Id="WixUIBannerBmp" Value="stage\banner.bmp" />')
} else {
    $wxsContent = $wxsContent.Replace("<!--{{BannerBmp}}-->", "")
}

$wxsPath = Join-Path $scriptRoot "project.wxs"
$wxsContent | Out-File -FilePath $wxsPath -Encoding utf8 -Force

Write-Host "Compiling installer..." -ForegroundColor Cyan
$candle = if ($wixDir) { Join-Path $wixDir "candle.exe" } else { "candle" }
$light = if ($wixDir) { Join-Path $wixDir "light.exe" } else { "light" }

$packagesDir = Join-Path $monorepoRoot "$AppName\dist\packages"
if (-not (Test-Path $packagesDir)) {
    $null = New-Item -ItemType Directory -Path $packagesDir -Force
}

$wixobjPath = Join-Path $scriptRoot "project.wixobj"
$msiOut = Join-Path $packagesDir "$AppName.msi"

& $candle "-out" $wixobjPath $wxsPath
& $light "-ext" "WixUIExtension" "-out" $msiOut $wixobjPath

# Clean up temp files
Remove-Item $wxsPath -ErrorAction SilentlyContinue
Remove-Item $wixobjPath -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $stageDir -ErrorAction SilentlyContinue

Write-Host "Installer built successfully at: $msiOut" -ForegroundColor Green
