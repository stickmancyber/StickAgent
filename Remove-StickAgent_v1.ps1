<#  
.SYNOPSIS
    Uninstalls Sysmon/Sysmon64 and the Wazuh Agent.
    • Developed By StickmanCyber - Nayan Bhattarai

.NOTES
    Run from an elevated PowerShell prompt.
    Add -Transcript to keep a log in %TEMP%.
#>

[CmdletBinding()]
param(
    [switch]$Transcript,
    [string]$TranscriptPath = "$env:TEMP\sysmon_uninstall_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
)

# -- Privilege check -----------------------------------------------------
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run from an elevated prompt."
    exit 1
}
if ($Transcript) { Start-Transcript -Path $TranscriptPath -Append }


function Uninstall-WazuhAgent {
    Write-Host "Searching for Stick Agent…" -ForegroundColor Cyan

    $agent = Get-CimInstance -ClassName Win32_Product `
                             -Filter "Name LIKE 'Wazuh Agent%'"

    if ($agent) {
        Write-Host "Uninstalling Stick Agent $($agent.Version)…" -ForegroundColor Cyan
        try {
            $result = Invoke-CimMethod -InputObject $agent -MethodName Uninstall
            switch ($result.ReturnValue) {
                0      { Write-Host "Stick Agent removed cleanly." -ForegroundColor Green }
                default{ Write-Warning "Uninstall completed with MSI code $($result.ReturnValue)." }
            }
        } catch {
            Write-Warning "Failed to uninstall Stick Agent: $_"
        }
    } else {
        Write-Host "Stick Agent not found in installed products." -ForegroundColor Yellow
    }

    $leftover = 'C:\Program Files (x86)\ossec-agent'
    if (Test-Path $leftover) {
        Write-Host "Removing leftover directory $leftover…" -ForegroundColor Cyan
        Remove-Item $leftover -Recurse -Force
    }
}

# -- MAIN ----------------------------------------------------------------
try {
    Uninstall-WazuhAgent
    Write-Host "`n Cleanup completed successfully." -ForegroundColor Green
} finally {
    if ($Transcript) { Stop-Transcript }
}