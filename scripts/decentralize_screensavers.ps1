# decentralize_screensavers.ps1
# Automates Phase 1 of the refactoring plan:
# - Copies each screensaver scene from library to the screensaver's repo.
# - Copies runtime.rs to each repo as runner.rs.
# - Updates crate:: imports to library::.
# - Removes #[cfg(feature = "...")] guards from imports.
# - Creates src/main.rs entrypoint linking runner & scene.
# - Updates Cargo.toml paths, target dependencies, and local patch block.
# - Runs cargo update -p library to refresh the lockfiles.

$ErrorActionPreference = "Stop"
$local76 = (Resolve-Path "$PSScriptRoot/../..").Path
Write-Host "local76 root: $local76" -ForegroundColor Cyan

$screens = @("beams", "bounce", "bursts", "chaos", "cosmos", "disco", "flame", "glyphs", "gnats", "storm")

# Map of lowercased scene names to their capitalized struct class names
$classMap = @{
    "beams"  = "Beams"
    "bounce" = "Bounce"
    "bursts" = "Bursts"
    "chaos"  = "Chaos"
    "cosmos" = "Cosmos"
    "disco"  = "Disco"
    "flame"  = "Flame"
    "glyphs" = "Glyphs"
    "gnats"  = "Gnats"
    "storm"  = "Storm"
}

foreach ($s in $screens) {
    Write-Host "`nProcessing screensavers-$s..." -ForegroundColor Yellow
    $repoPath = "$local76/screensavers-$s"
    if (-not (Test-Path $repoPath)) {
        Write-Host "Warning: directory $repoPath not found, skipping." -ForegroundColor Red
        continue;
    }

    # 1. Copy scene math code
    $srcScenePath = "$local76/library/src/screensavers/$s.rs"
    $destScenePath = "$repoPath/src/$s.rs"
    Copy-Item $srcScenePath $destScenePath -Force
    Write-Host "  - Copied math scene to src/$s.rs"

    # Update crate:: imports and remove feature cfg guards in the copied scene file
    $sceneContent = Get-Content $destScenePath -Raw
    $sceneContent = $sceneContent -replace 'use crate::', 'use library::'
    $sceneContent = $sceneContent -replace 'crate::core::', 'library::core::'
    $sceneContent = $sceneContent -replace 'crate::toolkit::', 'library::toolkit::'
    $sceneContent = $sceneContent -replace 'crate::platform::', 'library::platform::'
    $sceneContent = $sceneContent -replace 'crate::apps::', 'library::apps::'
    
    # Strip #[cfg(feature = "...")] guards preceding imports
    $sceneContent = $sceneContent -replace '(?m)^#\[cfg\(feature = "(sys-info|rgb|effects|widgets)"\)\]\s*$', ''
    
    Set-Content $destScenePath $sceneContent -NoNewline
    Write-Host "  - Updated crate:: imports & stripped cfg guards in src/$s.rs"

    # 2. Copy runner code
    $srcRunnerPath = "$local76/library/src/screensavers/runtime.rs"
    $destRunnerPath = "$repoPath/src/runner.rs"
    Copy-Item $srcRunnerPath $destRunnerPath -Force
    Write-Host "  - Copied runtime.rs to src/runner.rs"

    # Update crate:: imports and remove feature cfg guards in the runner file
    $runnerContent = Get-Content $destRunnerPath -Raw
    $runnerContent = $runnerContent -replace 'use crate::', 'use library::'
    $runnerContent = $runnerContent -replace 'crate::core::', 'library::core::'
    $runnerContent = $runnerContent -replace 'crate::toolkit::', 'library::toolkit::'
    $runnerContent = $runnerContent -replace 'crate::platform::', 'library::platform::'
    $runnerContent = $runnerContent -replace 'crate::apps::', 'library::apps::'
    
    # Strip #[cfg(feature = "...")] guards
    $runnerContent = $runnerContent -replace '(?m)^#\[cfg\(feature = "(sys-info|rgb|effects|widgets)"\)\]\s*$', ''
    
    Set-Content $destRunnerPath $runnerContent -NoNewline
    Write-Host "  - Updated imports & stripped cfg guards in src/runner.rs"

    # 3. Create src/main.rs entrypoint
    $className = $classMap[$s]
    $mainContent = @"
#![cfg_attr(
    all(not(debug_assertions), target_os = "windows"),
    windows_subsystem = "windows"
)]

mod runner;
mod $s;

fn main() {
    let effect = $s::${className}::new();
    runner::run_main(effect, "$s");
}
"@
    Set-Content "$repoPath/src/main.rs" $mainContent -NoNewline
    Write-Host "  - Created src/main.rs"

    # Remove the old shim file
    $shimPath = "$repoPath/src/screensaver_shim.rs"
    if (Test-Path $shimPath) {
        Remove-Item $shimPath -Force
        Write-Host "  - Removed src/screensaver_shim.rs"
    }

    # 4. Update Cargo.toml
    $tomlPath = "$repoPath/Cargo.toml"
    $tomlContent = Get-Content $tomlPath -Raw
    # Update bin path
    $tomlContent = $tomlContent -replace 'path = "src/screensaver_shim.rs"', 'path = "src/main.rs"'
    # Remove features = ["screensaver-runtime"]
    $tomlContent = $tomlContent -replace ', features = \["screensaver-runtime"\]', ''
    $tomlContent = $tomlContent -replace 'features = \["screensaver-runtime"\]', ''
    
    # Add patch section for local development if not already present
    if ($tomlContent -notlike "*[patch.`"https://github.com/local76/library.git`"]*") {
        $tomlContent += "`n[patch.`"https://github.com/local76/library.git`"]`nlibrary = { path = ""../library"" }`n"
    }
    
    # Add target-specific dependencies if not present
    if ($tomlContent -notlike "*[target.'cfg(not(target_os = ""windows""))'.dependencies]*") {
        $tomlContent += "`n[target.'cfg(not(target_os = ""windows""))'.dependencies]`nlibc = ""0.2""`n"
    }
    
    Set-Content $tomlPath $tomlContent -NoNewline
    Write-Host "  - Updated Cargo.toml"

    # 5. Run cargo update to sync lockfile
    Push-Location $repoPath
    try {
        cargo update -p library
    } finally {
        Pop-Location
    }
    Write-Host "  - Updated lockfile for local library path"
}

Write-Host "`nAll screensavers decoupled successfully." -ForegroundColor Green
