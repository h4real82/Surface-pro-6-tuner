<#
.SYNOPSIS
    Surface Pro 6 Tuner - Headless CLI & Automation Engine
.DESCRIPTION
    Main entry point for tuning, debloating, and unthrottling Microsoft Surface Pro 6 devices.
.EXAMPLE
    .\SurfaceTuner.ps1 -Profile All -AutoAccept -Headless
.EXAMPLE
    .\SurfaceTuner.ps1 -Status
.EXAMPLE
    .\SurfaceTuner.ps1 -Profile SurfacePerformance -DryRun
.EXAMPLE
    .\SurfaceTuner.ps1 -Rollback
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("All", "SurfacePerformance", "SurfaceBattery", "ThermalUnlock")]
    [string]$Profile = "All",

    [Parameter(Mandatory = $false)]
    [switch]$AutoAccept,

    [Parameter(Mandatory = $false)]
    [switch]$Headless,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Status,

    [Parameter(Mandatory = $false)]
    [switch]$Rollback,

    [Parameter(Mandatory = $false)]
    [string]$SnapshotFile
)

# 1. Administrator Elevation Check & Self-Elevation
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and -not $DryRun -and -not $Status) {
    if ($Headless) {
        Write-Error "ERROR: Administrator privileges required to write system settings. Run PowerShell as Administrator."
        exit 1
    }

    Write-Host "Elevating process to Administrator..." -ForegroundColor Yellow
    $scriptPath = $MyInvocation.MyCommand.Definition
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Profile $Profile"
    if ($AutoAccept) { $argList += " -AutoAccept" }
    if ($Headless) { $argList += " -Headless" }
    if ($Rollback) { $argList += " -Rollback" }

    Start-Process -FilePath "powershell.exe" -ArgumentList $argList -Verb RunAs
    exit 0
}

$projectRoot = $PSScriptRoot
. (Join-Path $projectRoot "src\engine\Job-Runner.ps1")
. (Join-Path $projectRoot "src\hardware\Thermal-Manager.ps1")
. (Join-Path $projectRoot "src\safety\Backup-Manager.ps1")

# 2. Hardware Status View
if ($Status) {
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host " Surface Pro 6 Hardware & Thermal Diagnostics           " -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan

    $hw = Get-SurfaceHardwareInfo
    Write-Host "Device: $($hw.Manufacturer) $($hw.Model)" -ForegroundColor White
    Write-Host "CPU:    $($hw.ProcessorName)" -ForegroundColor White
    Write-Host "Cores:  $($hw.NumberOfCores) Cores / $($hw.LogicalProcs) Threads" -ForegroundColor White
    Write-Host "Clock:  $($hw.CurrentClock) MHz (Max: $($hw.MaxClockSpeed) MHz)" -ForegroundColor White
    Write-Host "BIOS:   $($hw.BiosVersion)" -ForegroundColor White

    $thermal = Test-ProchotThrottling
    Write-Host "`nThrottling Status:" -ForegroundColor Yellow
    if ($thermal.IsSeverelyThrottled) {
        Write-Host "WARNING: CPU is throttled to $($thermal.CurrentClockSpeedMHz) MHz!" -ForegroundColor Red
    } else {
        Write-Host "Status: $($thermal.Recommendation)" -ForegroundColor Green
    }
    exit 0
}

# 3. Rollback Mode
if ($Rollback) {
    Write-Host "`n========================================================" -ForegroundColor Cyan
    Write-Host " Surface Pro 6 Tuner - Rollback Mode                    " -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan

    $snapshots = Get-RegistrySnapshots
    if (-not $snapshots) {
        Write-Host "No snapshots available in backups/." -ForegroundColor Yellow
        exit 0
    }

    $targetFile = $SnapshotFile
    if (-not $targetFile) {
        # Pick the most recent snapshot
        $latest = $snapshots[0]
        $targetFile = $latest.File
        Write-Host "Selected latest snapshot: $($latest.TweakId) ($($latest.Timestamp))" -ForegroundColor Cyan
    }

    Restore-RegistrySnapshot -SnapshotFilePath $targetFile
    Write-Host "Rollback completed successfully." -ForegroundColor Green
    exit 0
}

# 4. Profile Execution Mode
$results = @(Invoke-SurfaceTuningJob -ProfileId $Profile -DryRun:$DryRun -AutoAccept:$AutoAccept -Headless:$Headless)

if ($Headless) {
    # Output machine-readable JSON in headless mode
    $summary = [PSCustomObject]@{
        Profile   = $Profile
        DryRun    = [bool]$DryRun
        Timestamp = (Get-Date).ToString("o")
        Success   = ($results | Where-Object { $_.Status -in @("SUCCESS", "SKIPPED_ALREADY_APPLIED", "WOULD_APPLY") }).Count
        Blocked   = ($results | Where-Object { $_.Status -eq "BLOCKED" }).Count
        Errors    = ($results | Where-Object { $_.Status -eq "ERROR" }).Count
        Details   = $results
    }
    Write-Output ($summary | ConvertTo-Json -Depth 5)
}

exit 0
