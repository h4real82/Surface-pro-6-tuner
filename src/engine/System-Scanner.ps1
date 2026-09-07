<#
.SYNOPSIS
    Surface Pro 6 Tuner - System Health & Optimization Scanner
.DESCRIPTION
    Audits the current Windows environment against recommended Surface Pro 6
    tuning parameters, checks battery health and thermal throttling, and computes
    an overall Optimization Health Score.
#>

$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root "engine\Job-Runner.ps1")
. (Join-Path $root "hardware\Thermal-Manager.ps1")

function Get-SystemOptimizationStatus {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = (Join-Path $root "profiles\Tuning-Definitions.json")
    )

    $profiles = Get-TuningProfiles -ConfigPath $ConfigPath
    $auditItems = @()

    foreach ($profile in $profiles) {
        foreach ($tweak in $profile.tweaks) {
            $currentVal = $null
            $isOptimized = $false

            if (Test-Path $tweak.path) {
                $prop = Get-ItemProperty -Path $tweak.path -Name $tweak.valueName -ErrorAction SilentlyContinue
                if ($null -ne $prop) {
                    $currentVal = $prop.$($tweak.valueName)
                }
            }

            if ($currentVal -eq $tweak.targetValue) {
                $isOptimized = $true
            }

            $auditItems += [PSCustomObject]@{
                Id               = $tweak.id
                ProfileId        = $profile.id
                ProfileName      = $profile.name
                Description      = $tweak.description
                Path             = $tweak.path
                ValueName        = $tweak.valueName
                TargetValue      = $tweak.targetValue
                CurrentValue     = $(if ($null -eq $currentVal) { "Nicht konfiguriert (Standard)" } else { $currentVal })
                IsOptimized      = $isOptimized
                StatusText       = $(if ($isOptimized) { "Optimiert" } else { "Optimierung verfuegbar" })
                Impact           = $(if ($tweak.id -like "*Thermal*" -or $tweak.id -like "*Standby*") { "Hoch" } else { "Mittel" })
            }
        }
    }

    # Audit Hardware & Throttling
    $hw = Get-SurfaceHardwareInfo
    $thermal = Test-ProchotThrottling
    $auditItems += [PSCustomObject]@{
        Id               = "ThermalThrottlingCheck"
        ProfileId        = "HardwareHealth"
        ProfileName      = "Hardware & Kuehlung"
        Description      = "Ueberprueft ob der 400 MHz BD-PROCHOT Thermal-Lock aktiv ist"
        Path             = "Hardware / CPU"
        ValueName        = "ClockSpeed"
        TargetValue      = "> 1600 MHz"
        CurrentValue     = "$($thermal.CurrentClockSpeedMHz) MHz"
        IsOptimized      = (-not $thermal.IsSeverelyThrottled)
        StatusText       = $(if (-not $thermal.IsSeverelyThrottled) { "Normal" } else { "Drosselung aktiv!" })
        Impact           = "Kritisch"
    }

    # Battery Health Check
    try {
        $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
        if ($battery) {
            $auditItems += [PSCustomObject]@{
                Id               = "BatteryHealth"
                ProfileId        = "HardwareHealth"
                ProfileName      = "Hardware & Kuehlung"
                Description      = "Akkuzustand und Ladestatus"
                Path             = "Hardware / Akku"
                ValueName        = "EstimatedChargeRemaining"
                TargetValue      = "Gesund"
                CurrentValue     = "$($battery.EstimatedChargeRemaining)% ($($battery.Status))"
                IsOptimized      = $true
                StatusText       = "Geprueft"
                Impact           = "Info"
            }
        }
    } catch {
        # Optional CIM query failure gracefully ignored
    }

    $totalTuning = ($auditItems | Where-Object { $_.ProfileId -ne "HardwareHealth" }).Count
    $optimizedTuning = ($auditItems | Where-Object { $_.ProfileId -ne "HardwareHealth" -and $_.IsOptimized }).Count

    $score = 0
    if ($totalTuning -gt 0) {
        $score = [int][Math]::Round(($optimizedTuning / $totalTuning) * 100)
    }

    return [PSCustomObject]@{
        ScorePercent     = $score
        TotalItems       = $totalTuning
        OptimizedCount   = $optimizedTuning
        PendingCount     = ($totalTuning - $optimizedTuning)
        Items            = $auditItems
        HardwareInfo     = $hw
    }
}

function Invoke-SystemTweakFix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TweakId
    )

    $profiles = Get-TuningProfiles
    $targetTweak = $null
    foreach ($p in $profiles) {
        foreach ($t in $p.tweaks) {
            if ($t.id -eq $TweakId) {
                $targetTweak = $t
                break
            }
        }
        if ($targetTweak) { break }
    }

    if (-not $targetTweak) {
        throw "Tweak [$TweakId] nicht im Profilkatalog gefunden."
    }

    # Apply via Job-Runner
    $snapshot = New-RegistrySnapshot -TweakId $targetTweak.id `
        -RegistryPath $targetTweak.path `
        -ValueName $targetTweak.valueName `
        -Description $targetTweak.description

    if (-not (Test-Path $targetTweak.path)) {
        New-Item -Path $targetTweak.path -Force | Out-Null
    }

    if ($targetTweak.type -eq "DWord") {
        Set-ItemProperty -Path $targetTweak.path -Name $targetTweak.valueName -Value ([int]$targetTweak.targetValue) -Type DWord -Force
    } elseif ($targetTweak.type -eq "QWord") {
        Set-ItemProperty -Path $targetTweak.path -Name $targetTweak.valueName -Value ([int64]$targetTweak.targetValue) -Type QWord -Force
    } else {
        Set-ItemProperty -Path $targetTweak.path -Name $targetTweak.valueName -Value $targetTweak.targetValue -Type String -Force
    }

    return [PSCustomObject]@{
        TweakId  = $targetTweak.id
        Status   = "SUCCESS"
        Snapshot = (Split-Path $snapshot.SnapshotFile -Leaf)
    }
}
