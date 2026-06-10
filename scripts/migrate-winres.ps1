# migrate-winres.ps1 — idempotently migrate a local76 crate's build.rs from
# winres 0.1 to embed-resource 2.x
#
# Strategy:
#   1. For each crate's build.rs that calls winres::WindowsResource::new(),
#      rewrite it to call library::build_resources::prepare_icon + the new
#      embed-resource 2.x template.
#   2. For each Cargo.toml that declares `winres` in [build-dependencies]
#      (or [target.'cfg(windows)'.build-dependencies]), replace it with
#      `embed-resource = "2"`.
#   3. Re-run `cargo build --release` for the affected crates.
#   4. Re-run verify-icon.ps1 on the resulting dist/binaries.
#
# Idempotent: re-running on an already-migrated repo is a no-op for the
# file edits (the rewrite is a no-op because the marker comment is
# already in the file) and re-runs the build + verify.
#
# Usage:
#   pwsh ./toolkit/scripts/migrate-winres.ps1 -Root ../screensavers -Binaries ../screensavers/dist/binaries
#   pwsh ./toolkit/scripts/migrate-winres.ps1 -Root ../helm -Binaries ../helm/dist/binaries
#   pwsh ./toolkit/scripts/migrate-winres.ps1 -Root ../ -Binaries ../dist/binaries  # whole monorepo

param(
    [Parameter(Mandatory = $true)]
    [string]$Root,
    [string]$Binaries,
    [switch]$SkipBuild,
    [switch]$SkipVerify,
    [string]$VerifyScript = (Join-Path $PSScriptRoot "verify-icon.ps1")
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path $Root).Path
if (-not $Binaries) { $Binaries = Join-Path $Root "dist/binaries" }

$marker = "library::build_resources::prepare_icon"

function Rewrite-BuildRs {
    param([string]$Path)

    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -match [regex]::Escape($marker)) {
        return [PSCustomObject]@{ Path = $Path; Changed = $false; Note = "already migrated" }
    }
    if ($content -notmatch 'winres::WindowsResource::new\(\)') {
        return $null
    }

    $relative = (Resolve-Path $Path).Path
    Write-Host "  rewriting: $relative" -ForegroundColor Yellow

    $icoMatch = [regex]::Match($content, 'res\.set_icon\("([^"]+)"\)')
    if (-not $icoMatch.Success) {
        $icoMatch = [regex]::Match($content, 'res\.set_icon\(([^)]+)\)')
    }
    $icoArg = if ($icoMatch.Success) { $icoMatch.Groups[1].Value } else { '"assets/icon.ico"' }

    $metaLines = @()
    $fdMatch = [regex]::Match($content, 'res\.set\("FileDescription",\s*"([^"]+)"\)')
    $pnMatch = [regex]::Match($content, 'res\.set\("ProductName",\s*"([^"]+)"\)')
    $cnMatch = [regex]::Match($content, 'res\.set\("CompanyName",\s*"([^"]+)"\)')
    $lcMatch = [regex]::Match($content, 'res\.set\("LegalCopyright",\s*"([^"]+)"\)')
    if ($fdMatch.Success) { $metaLines += ('rc.set("FileDescription", "{0}");' -f $fdMatch.Groups[1].Value) }
    else                  { $metaLines += 'rc.set("FileDescription", &meta.file_description);' }
    if ($pnMatch.Success) { $metaLines += ('rc.set("ProductName", "{0}");' -f $pnMatch.Groups[1].Value) }
    else                  { $metaLines += 'rc.set("ProductName", library::build_resources::DEFAULT_PRODUCT_NAME);' }
    if ($cnMatch.Success) { $metaLines += ('rc.set("CompanyName", "{0}");' -f $cnMatch.Groups[1].Value) }
    else                  { $metaLines += 'rc.set("CompanyName", library::build_resources::DEFAULT_COMPANY_NAME);' }
    if ($lcMatch.Success) { $metaLines += ('rc.set("LegalCopyright", "{0}");' -f $lcMatch.Groups[1].Value) }
    else                  { $metaLines += 'rc.set("LegalCopyright", library::build_resources::DEFAULT_LEGAL_COPYRIGHT);' }

    $newContent = @"
use std::path::Path;

fn main() {
    println!("cargo:rerun-if-changed=$icoArg");
    let ico_path = Path::new($icoArg);

    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();
    if target_os == "windows" && ico_path.exists() {
        // Migrated from winres 0.1 to embed-resource 2.x via
        // library::build_resources::prepare_icon (see library/docs/VISUAL_STANDARDS.md).
        if let Some((icon_path, meta)) = library::build_resources::prepare_icon(ico_path) {
            let mut rc = embed_resource::new();
            rc.set_icon(&icon_path);
$($metaLines | ForEach-Object { "            $_" })
            rc.compile().expect("failed to compile winres resource");
        }
    }
}
"@

    Set-Content -LiteralPath $Path -Value $newContent -NoNewline
    return [PSCustomObject]@{ Path = $Path; Changed = $true; Note = "rewritten" }
}

function Rewrite-CargoToml {
    param([string]$Path)

    $content = Get-Content -LiteralPath $Path -Raw
    if ($content -match 'embed-resource\s*=\s*"2"') {
        return [PSCustomObject]@{ Path = $Path; Changed = $false; Note = "already on embed-resource" }
    }
    if ($content -notmatch '(?m)^\s*winres\s*=\s*"0\.1"') {
        return $null
    }

    $relative = (Resolve-Path $Path).Path
    Write-Host "  rewriting: $relative" -ForegroundColor Yellow

    # Drop the plain [build-dependencies] winres line if present.
    $new = [regex]::Replace($content, '(?m)^\s*winres\s*=\s*"0\.1"\s*\r?\n', '')
    # Add embed-resource under [build-dependencies] (or the windows-target section).
    if ($new -match '(?ms)\[target\.\x27cfg\(windows\)\x27\.build-dependencies\](?:\r?\n[^\[]*)?') {
        $section = $Matches[0]
        $replacement = $section.TrimEnd() + "`r`nwinres = { version = `"0.1`", optional = true }`r`nembed-resource = `"2`"`r`n"
        $new = $new.Replace($section, $replacement)
    } elseif ($new -match '(?ms)\[build-dependencies\](?:\r?\n[^\[]*)?') {
        $section = $Matches[0]
        $replacement = $section.TrimEnd() + "`r`nwinres = { version = `"0.1`", optional = true }`r`nembed-resource = `"2`"`r`n"
        $new = $new.Replace($section, $replacement)
    } else {
        $new += "`r`n`r`n[build-dependencies]`r`nembed-resource = `"2`"`r`n"
    }

    Set-Content -LiteralPath $Path -Value $new -NoNewline
    return [PSCustomObject]@{ Path = $Path; Changed = $true; Note = "swapped dep" }
}

$buildRsFiles = Get-ChildItem -LiteralPath $Root -Recurse -Filter 'build.rs' -ErrorAction SilentlyContinue
$cargoTomls   = Get-ChildItem -LiteralPath $Root -Recurse -Filter 'Cargo.toml' -ErrorAction SilentlyContinue

"`n=== Step 1: rewrite build.rs files ==="
$buildChanges = foreach ($f in $buildRsFiles) {
    $r = Rewrite-BuildRs -Path $f.FullName
    if ($r) { $r }
}
$buildChanges | Format-Table -AutoSize -Wrap

"`n=== Step 2: rewrite Cargo.toml files ==="
$cargoChanges = foreach ($f in $cargoTomls) {
    $r = Rewrite-CargoToml -Path $f.FullName
    if ($r) { $r }
}
$cargoChanges | Format-Table -AutoSize -Wrap

if (-not $SkipBuild) {
    "`n=== Step 3: cargo build --release ==="
    Push-Location $Root
    try {
        $env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
        & cargo build --release 2>&1 | Select-String -Pattern 'error|Compiling|Finished' | Select-Object -Last 30
    } finally {
        Pop-Location
    }
}

if (-not $SkipVerify) {
    "`n=== Step 4: verify-icon ==="
    if (Test-Path -LiteralPath $VerifyScript) {
        & pwsh -NoProfile -ExecutionPolicy Bypass -File $VerifyScript -BinDir $Binaries
    } else {
        Write-Warning "verify-icon.ps1 not found at $VerifyScript — skipping"
    }
}
