#!/usr/bin/env pwsh
# notify-release.ps1 — Windows toast notification on release success/failure.
#
# Uses the Windows.UI.Notifications API via PowerShell. Falls back to
# a Write-Host banner if BurntToast isn't installed.

param(
    [ValidateSet("success", "failure")]
    [string]$Kind = "success",
    [string]$Version = "",
    [string]$Message = ""
)

if (-not $Message) {
    if ($Kind -eq "success") {
        $Message = "local76: released v$Version"
    } else {
        $Message = "local76: release failed"
    }
}

# Try BurntToast first
if (Get-Module -ListAvailable -Name BurntToast) {
    try {
        Import-Module BurntToast
        if ($Kind -eq "success") {
            New-BurntToastNotification -Text "local76 release", $Message
        } else {
            New-BurntToastNotification -Text "local76 release FAILED", $Message
        }
        exit 0
    } catch {
        # Fall through to fallback
    }
}

# Fallback: Windows 10+ toast via the .NET toast API
try {
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    $template = [Windows.UI.Notifications.ToastTemplateType]::ToastText02
    $xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent($template)
    $textNodes = $xml.GetElementsByTagName("text")
    $textNodes.Item(0).AppendChild($xml.CreateTextNode("local76 release")) | Out-Null
    $textNodes.Item(1).AppendChild($xml.CreateTextNode($Message)) | Out-Null
    $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("local76").Show($toast)
} catch {
    # Final fallback: just write to host
    if ($Kind -eq "success") {
        Write-Host "[OK] $Message" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Message" -ForegroundColor Red
    }
}
