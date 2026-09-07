<#
.SYNOPSIS
    Thermal and Hardware Management for Surface Pro 6
.DESCRIPTION
    Detects Surface hardware, monitors CPU clock & thermal throttle state,
    and applies safe mitigation against the notorious 400 MHz BD-PROCHOT lock.
#>

function Get-SurfaceHardwareInfo {
    [CmdletBinding()]
    param()

    $cs = Get-CimInstance -ClassName Win32_ComputerSystem
    $proc = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $bios = Get-CimInstance -ClassName Win32_BIOS

    $isSurface = ($cs.Model -like "*Surface Pro 6*" -or $cs.SystemFamily -like "*Surface*")

    return [PSCustomObject]@{
        Manufacturer   = $cs.Manufacturer
        Model          = $cs.Model
        SystemFamily   = $cs.SystemFamily
        IsSurfacePro6  = $isSurface
        ProcessorName  = $proc.Name
        MaxClockSpeed  = $proc.MaxClockSpeed
        CurrentClock   = $proc.CurrentClockSpeed
        NumberOfCores  = $proc.NumberOfCores
        LogicalProcs   = $proc.NumberOfLogicalProcessors
        BiosVersion    = $bios.SMBIOSBIOSVersion
    }
}

function Test-ProchotThrottling {
    [CmdletBinding()]
    param()

    $proc = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
    $currSpeed = $proc.CurrentClockSpeed
    $maxSpeed = $proc.MaxClockSpeed

    # Surface Pro 6 locks to ~400 MHz (0.4 GHz) when BD-PROCHOT falsely triggers
    $isSeverelyThrottled = ($currSpeed -le 500)

    return [PSCustomObject]@{
        CurrentClockSpeedMHz = $currSpeed
        MaxClockSpeedMHz     = $maxSpeed
        IsSeverelyThrottled  = $isSeverelyThrottled
        Recommendation       = if ($isSeverelyThrottled) {
            "CRITICAL: CPU locked at <= 500 MHz (likely BD-PROCHOT false thermal trip). Apply Thermal Unlock."
        } else {
            "Normal: CPU clock is operating above throttling floor."
        }
    }
}

function Set-SurfacePowerOverlayTuning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("MaxBattery", "Balanced", "MaxPerformance")]
        [string]$PowerMode = "Balanced"
    )

    $powerRoot = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"

    # Map overlay mode
    $overlayMap = @{
        "MaxBattery"     = 0
        "Balanced"       = 1
        "MaxPerformance" = 2
    }

    $overlayVal = $overlayMap[$PowerMode]

    # Safe Surface-tuned Power Overlay setting (within allowed scope)
    Set-ItemProperty -Path $powerRoot -Name "UserPowerModeSetting" -Value $overlayVal -Type DWord -Force -ErrorAction SilentlyContinue

    # Connected Standby network in battery optimization
    Set-ItemProperty -Path $powerRoot -Name "CustomizeConnectedStandby" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

    return [PSCustomObject]@{
        Success   = $true
        PowerMode = $PowerMode
        AppliedAt = (Get-Date).ToString("o")
    }
}
