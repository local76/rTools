#!/usr/bin/env pwsh
# install-daily-task.ps1 — one-time setup.
#
# Registers the daily 04:00 PT release task in Windows Task Scheduler.
# -WakeToRun so the machine wakes from sleep at 04:00.
# -StartWhenAvailable so a missed run catches up at next boot.
# Runlevel Highest so the task runs even if the user isn't logged in.

param(
    [string]$MonorepoRoot = (Resolve-Path "$PSScriptRoot/../.."),
    [string]$Time = "04:00"
)

$ErrorActionPreference = "Stop"
$taskName = "local76-daily-release"
$scriptPath = Join-Path $MonorepoRoot "toolkit/scripts/daily-release.ps1"

Write-Host "Registering Windows Task Scheduler job:" -ForegroundColor Cyan
Write-Host "  Name:     $taskName"
Write-Host "  Time:     $Time daily (local time)"
Write-Host "  Script:   $scriptPath"
Write-Host ""

# Remove any pre-existing task with the same name
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

$action = New-ScheduledTaskAction `
    -Execute "pwsh.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" `
    -WorkingDirectory $MonorepoRoot

$trigger = New-ScheduledTaskTrigger -Daily -At $Time

$settings = New-ScheduledTaskSettingsSet `
    -WakeToRun `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 5)

$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Daily local76 release: build + tag + publish if any repo has new commits on origin/main since the last tag. Runs at $Time local time."

Write-Host "Task registered. To verify:" -ForegroundColor Green
Write-Host "  Get-ScheduledTask -TaskName $taskName"
Write-Host ""
Write-Host "To run manually:" -ForegroundColor Green
Write-Host "  Start-ScheduledTask -TaskName $taskName"
Write-Host ""
Write-Host "To remove:" -ForegroundColor Green
Write-Host "  Unregister-ScheduledTask -TaskName $taskName -Confirm:`$false"
