#!/usr/bin/env pwsh
# toolkit/scripts/push_all.ps1
# Tag and push a release tag across every local76 repo. Idempotent: skips repos
# that already have the tag.
# Usage: pwsh ./toolkit/scripts/push_all.ps1 -Tag v1.0.0 [-DryRun] [-Message "..."]
#        pwsh ./toolkit/scripts/push_all.ps1 -Tag v1.0.0 -Repos library,helm

param(
    [Parameter(Mandatory = $true)]
    [string]$Tag,

    [string]$Message = "",

    [string[]]$Repos = @(
        "library",
        "app-helm",
        "app-pulse",
        "app-scout",
        "app-trance",
        "app-ignite",
        "screensavers-beams",
        "screensavers-bounce",
        "screensavers-bursts",
        "screensavers-chaos",
        "screensavers-cosmos",
        "screensavers-disco",
        "screensavers-flame",
        "screensavers-glyphs",
        "screensavers-gnats",
        "screensavers-storm",
        "toolkit",
        "local76"
    ),

    [switch]$DryRun = $false
)

$ErrorActionPreference = "Stop"

# toolkit/ lives at <monorepo>/toolkit. The sibling repos are in the same monorepo root.
$monorepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")

if ([string]::IsNullOrWhiteSpace($Message)) {
    $Message = "Tag $Tag — local76 ecosystem release"
}

function Push-Tag-One {
    param(
        [string]$Path,
        [string]$Name,
        [string]$Tag,
        [string]$Message,
        [bool]$DryRun
    )

    if (-not (Test-Path $Path)) {
        Write-Host "[skip ] $Name — path not found: $Path" -ForegroundColor DarkGray
        return
    }

    Push-Location $Path
    try {
        # Idempotency check: skip if the tag already exists locally.
        $existing = git tag -l $Tag
        if ($existing) {
            Write-Host "[have ] $Name — $Tag already present locally" -ForegroundColor DarkYellow
        } else {
            if ($DryRun) {
                Write-Host "[dry  ] $Name — would create $Tag" -ForegroundColor DarkCyan
            } else {
                git tag -a $Tag -m $Message
                if ($LASTEXITCODE -ne 0) {
                    throw "git tag failed in $Name"
                }
                Write-Host "[tag  ] $Name — created $Tag" -ForegroundColor Green
            }
        }

        # Push (always; safe because the push is a no-op if the tag is already on the remote).
        if ($DryRun) {
            Write-Host "[dry  ] $Name — would push $Tag" -ForegroundColor DarkCyan
        } else {
            git push origin $Tag
            if ($LASTEXITCODE -ne 0) {
                throw "git push failed in $Name for tag $Tag"
            }
            Write-Host "[push ] $Name — pushed $Tag" -ForegroundColor Green
        }
    } finally {
        Pop-Location
    }
}

foreach ($r in $Repos) {
    $path = Join-Path $monorepoRoot $r
    if (-not (Test-Path $path)) {
        if ($r -match "^(helm|pulse|scout|trance|ignite)$") {
            $path = Join-Path $monorepoRoot "app-$r"
        } elseif ($r -match "^(beams|bounce|bursts|chaos|cosmos|disco|flame|glyphs|gnats|storm)$") {
            $path = Join-Path $monorepoRoot "screensavers-$r"
        }
    }
    Push-Tag-One -Path $path -Name $r -Tag $Tag -Message $Message -DryRun $DryRun
}

Write-Host ""
Write-Host "push_all.ps1 complete." -ForegroundColor Green
