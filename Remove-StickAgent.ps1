 <#  
.SYNOPSIS
    Uninstalls the Stick Agent.
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

function Uninstall-StickAgent {
    Write-Host "Searching for StickAgent..." -ForegroundColor Cyan

    $agent = Get-CimInstance -ClassName Win32_Product ` -Filter "Name LIKE 'StickContr%'"

    if ($agent) {
        Write-Host "Uninstalling Stick Agent $($agent.Version)..." -ForegroundColor Cyan
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

    $leftover = 'C:\Program Files (x86)\StickAgent'
    if (Test-Path $leftover) {
        Write-Host "Removing leftover directory $leftover..." -ForegroundColor Cyan
        Remove-Item $leftover -Recurse -Force
    }
}

# -- MAIN ----------------------------------------------------------------
try {
    Uninstall-StickAgent
    Write-Host "`nCleanup completed successfully." -ForegroundColor Green
} finally {
    if ($Transcript) { Stop-Transcript }
} 

