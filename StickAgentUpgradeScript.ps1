 <#  
.SYNOPSIS
    Uninstalls and the Wazuh Agent.
    • Developed By Nayan Bhattarai - StickmanCyber

.NOTES
    Run from an elevated PowerShell prompt.
    Add -Transcript to keep a log in %TEMP%.
#>

[CmdletBinding()]
param(
    [switch]$Transcript,
    [string]$TranscriptPath = "$env:TEMP\StickAgent_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
)

# -- Privilege check -----------------------------------------------------
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run from an elevated prompt."
    exit 1
}
if ($Transcript) { Start-Transcript -Path $TranscriptPath -Append }

# -- FUNCTIONS -----------------------------------------------------------
function Uninstall-WazuhAgent {
    Write-Host "Searching for Older StickAgent..." -ForegroundColor Cyan

    $agent = Get-CimInstance -ClassName Win32_Product `
                             -Filter "Name LIKE 'Wazuh Agent%'"

    if ($agent) {
        Write-Host "Uninstalling Older StickAgent $($agent.Version)..." -ForegroundColor Cyan
        try {
            $result = Invoke-CimMethod -InputObject $agent -MethodName Uninstall
            switch ($result.ReturnValue) {
                0      { Write-Host "StickAgent removed cleanly." -ForegroundColor Green }
                default{ Write-Warning "Uninstall completed with MSI code $($result.ReturnValue)." }
            }
        } catch {
            Write-Warning "Failed to uninstall SitckAgent: $_"
        }
    } else {
        Write-Host "StickAgent not found in installed products." -ForegroundColor Yellow
    }

    $leftover = 'C:\Program Files (x86)\ossec-agent'
    if (Test-Path $leftover) {
        Write-Host "Removing leftover directory $leftover..." -ForegroundColor Green
        Remove-Item $leftover -Recurse -Force
    }
}

function Install-BindPlane {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, HelpMessage="Enter the Secret Key for BindPlane.")]
        [string]$OpAmpSecretKey
    )

    $msiUrl = "https://bdot.bindplane.com/v1.93.0/observiq-otel-collector.msi"
    $tempPath = Join-Path $env:TEMP "observiq-otel-collector.msi"

    Write-Host "Downloading agent installer..." -ForegroundColor Cyan
    try {
        # Using -ErrorAction Stop to catch network failures in the catch block
        Invoke-WebRequest -Uri $msiUrl -OutFile $tempPath -ErrorAction Stop
    } catch {
        Write-Error "Failed to download installer: $_"
        return
    }

    Write-Host "Starting silent installation..." -ForegroundColor Gray

    # Constructing arguments for msiexec
    $msiArgs = @(
        "/i", "`"$tempPath`"",
        "/quiet",
        "/norestart",
        "ENABLEMANAGEMENT=`"1`"",
        "OPAMPENDPOINT=`"wss://app.bindplane.com/v1/opamp`"",
        "OPAMPSECRETKEY=`"$OpAmpSecretKey`""
    )

    try {
        # Start-Process allows us to wait for completion and capture the exit code
        $process = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru
        
        switch ($process.ExitCode) {
            0    { Write-Host "Installation completed successfully." -ForegroundColor Green }
            3010 { Write-Host "Installation successful, but a reboot is required." -ForegroundColor Yellow }
            default { Write-Warning "Installation failed with MSI exit code $($process.ExitCode)." }
        }
    } catch {
        Write-Error "An error occurred during the msiexec process: $_"
    } finally {
        # Clean up the temporary MSI file
        if (Test-Path $tempPath) {
            Write-Host "Cleaning up temporary files..." -ForegroundColor Green
            Remove-Item $tempPath -Force
        }
    }
}

# -- MAIN ----------------------------------------------------------------
try {
    Install-BindPlane
    Uninstall-WazuhAgent
    Write-Host "`n Cleanup completed successfully." -ForegroundColor Green
} finally {
    if ($Transcript) { Stop-Transcript }
} 
