<#
.SYNOPSIS
    Surface Pro 6 Tuner Execution Engine & Job Runner
.DESCRIPTION
    Asynchronously or synchronously runs tuning tasks with pre-execution safety gates,
    snapshot capture, and automated verification.
#>

$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root "safety\Registry-Validator.ps1")
. (Join-Path $root "safety\Backup-Manager.ps1")
. (Join-Path $root "hardware\Thermal-Manager.ps1")

function Get-TuningProfiles {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = (Join-Path $root "profiles\Tuning-Definitions.json")
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Tuning definitions file not found at: $ConfigPath"
    }

    $raw = Get-Content -Path $ConfigPath -Raw -Encoding utf8
    return ($raw | ConvertFrom-Json).profiles
}

function Invoke-SurfaceTuningJob {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ProfileId = "All",

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [switch]$AutoAccept,

        [Parameter(Mandatory = $false)]
        [switch]$Headless
    )

    $profiles = Get-TuningProfiles
    $selectedProfiles = @()

    if ($ProfileId -eq "All") {
        $selectedProfiles = $profiles
    } else {
        $selectedProfiles = $profiles | Where-Object { $_.id -eq $ProfileId }
        if (-not $selectedProfiles) {
            throw "Profile [$ProfileId] not found. Available: $(($profiles.id) -join ', ')"
        }
    }

    $results = @()

    if (-not $Headless) {
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host " Surface Pro 6 Tuner - Execution Engine                   " -ForegroundColor Cyan
        Write-Host " Mode: $(if ($DryRun) { 'DRY RUN (Read-Only)' } else { 'APPLY' }) | AutoAccept: $(if ($AutoAccept) { 'YES' } else { 'NO' }) " -ForegroundColor Cyan
        Write-Host "==========================================================" -ForegroundColor Cyan
    }

    foreach ($profile in $selectedProfiles) {
        if (-not $Headless) { Write-Host "`n>>> Processing Profile: [$($profile.name)]" -ForegroundColor Yellow }

        foreach ($tweak in $profile.tweaks) {
            if (-not $Headless) { Write-Host -NoNewline "  - [$($tweak.id)]: $($tweak.description)... " }

            # Step 1: Safety Gate
            $safety = Test-TweakSafety -RegistryPath $tweak.path -ValueName $tweak.valueName

            if (-not $safety.IsSafe) {
                if (-not $Headless) {
                    Write-Host "[BLOCKED]" -ForegroundColor Red
                    Write-Host "    Reason: $($safety.Reason)" -ForegroundColor DarkRed
                }
                $results += [PSCustomObject]@{
                    TweakId     = $tweak.id
                    Status      = "BLOCKED"
                    Reason      = $safety.Reason
                    DryRun      = $DryRun
                }
                continue
            }

            # Step 2: Check current state
            $currentVal = $null
            if (Test-Path $tweak.path) {
                $prop = Get-ItemProperty -Path $tweak.path -Name $tweak.valueName -ErrorAction SilentlyContinue
                if ($null -ne $prop) {
                    $currentVal = $prop.$($tweak.valueName)
                }
            }

            if ($currentVal -eq $tweak.targetValue) {
                if (-not $Headless) { Write-Host "[ALREADY APPLIED]" -ForegroundColor DarkGray }
                $results += [PSCustomObject]@{
                    TweakId     = $tweak.id
                    Status      = "SKIPPED_ALREADY_APPLIED"
                    CurrentVal  = $currentVal
                    TargetVal   = $tweak.targetValue
                    DryRun      = $DryRun
                }
                continue
            }

            if ($DryRun) {
                if (-not $Headless) {
                    Write-Host "[WOULD APPLY]" -ForegroundColor Magenta
                    Write-Host "    Current: $currentVal -> Target: $($tweak.targetValue) ($($tweak.type))" -ForegroundColor DarkMagenta
                }
                $results += [PSCustomObject]@{
                    TweakId     = $tweak.id
                    Status      = "WOULD_APPLY"
                    CurrentVal  = $currentVal
                    TargetVal   = $tweak.targetValue
                    DryRun      = $true
                }
                continue
            }

            # Step 3: Create Pre-Tweak Safety Snapshot
            try {
                $snapshot = New-RegistrySnapshot -TweakId $tweak.id `
                    -RegistryPath $tweak.path `
                    -ValueName $tweak.valueName `
                    -Description $tweak.description

                # Step 4: Apply Modification
                if (-not (Test-Path $tweak.path)) {
                    New-Item -Path $tweak.path -Force | Out-Null
                }

                if ($tweak.type -eq "DWord") {
                    Set-ItemProperty -Path $tweak.path -Name $tweak.valueName -Value ([int]$tweak.targetValue) -Type DWord -Force
                } elseif ($tweak.type -eq "QWord") {
                    Set-ItemProperty -Path $tweak.path -Name $tweak.valueName -Value ([int64]$tweak.targetValue) -Type QWord -Force
                } else {
                    Set-ItemProperty -Path $tweak.path -Name $tweak.valueName -Value $tweak.targetValue -Type String -Force
                }

                # Step 5: Verify
                $verifyProp = Get-ItemProperty -Path $tweak.path -Name $tweak.valueName
                if ($verifyProp.$($tweak.valueName) -eq $tweak.targetValue) {
                    if (-not $Headless) { Write-Host "[SUCCESS]" -ForegroundColor Green }
                    $results += [PSCustomObject]@{
                        TweakId     = $tweak.id
                        Status      = "SUCCESS"
                        Snapshot    = (Split-Path $snapshot.SnapshotFile -Leaf)
                        DryRun      = $false
                    }
                } else {
                    if (-not $Headless) { Write-Host "[VERIFY FAILED]" -ForegroundColor Red }
                    $results += [PSCustomObject]@{
                        TweakId     = $tweak.id
                        Status      = "VERIFICATION_FAILED"
                        DryRun      = $false
                    }
                }
            } catch {
                if (-not $Headless) { Write-Host "[ERROR: $_]" -ForegroundColor Red }
                $results += [PSCustomObject]@{
                    TweakId     = $tweak.id
                    Status      = "ERROR"
                    Error       = $_.ToString()
                    DryRun      = $false
                }
            }
        }
    }

    if (-not $Headless) {
        Write-Host "`nSummary: $($results.Count) Tweaks evaluated." -ForegroundColor Cyan
    }
    return $results
}
