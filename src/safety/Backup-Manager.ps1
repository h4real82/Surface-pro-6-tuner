<#
.SYNOPSIS
    Registry Backup and Restore Manager for Surface Pro 6 Tuner
.DESCRIPTION
    Provides pre-tweak snapshot creation and 1-click restore functionality
    inspired by Win11Debloat's state management patterns.
#>

. (Join-Path $PSScriptRoot "Registry-Validator.ps1")

function Get-BackupStorageDir {
    [CmdletBinding()]
    param()
    $dir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) "backups"
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    return $dir
}

function New-RegistrySnapshot {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$TweakId,

        [Parameter(Mandatory = $true)]
        [string]$RegistryPath,

        [Parameter(Mandatory = $false)]
        [string]$ValueName = "",

        [Parameter(Mandatory = $false)]
        [string]$Description = "Automatic Pre-Tweak Snapshot",

        [Parameter(Mandatory = $false)]
        [switch]$SkipValidation
    )

    # 1. Safety Validation Gate
    if (-not $SkipValidation) {
        $check = Test-TweakSafety -RegistryPath $RegistryPath -ValueName $ValueName
        if (-not $check.IsSafe) {
            throw "SAFETY GATE BLOCKED: $($check.Reason)"
        }
    }

    $timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
    $backupDir = Get-BackupStorageDir
    $snapshotFile = Join-Path $backupDir "snapshot_${timestamp}_${TweakId}.json"

    $keyExists = Test-Path -Path $RegistryPath
    $originalValue = $null
    $originalKind = "None"
    $valueExists = $false

    if ($keyExists -and $ValueName) {
        try {
            $item = Get-ItemProperty -Path $RegistryPath -Name $ValueName -ErrorAction SilentlyContinue
            if ($null -ne $item -and ($item.PSObject.Properties.Name -contains $ValueName)) {
                $originalValue = $item.$ValueName
                $valueExists = $true

                $regKey = Get-Item -Path $RegistryPath
                $originalKind = $regKey.GetValueKind($ValueName).ToString()
            }
        } catch {
            Write-Verbose "Could not read original value: $_"
        }
    }

    $snapshotData = [PSCustomObject]@{
        TweakId        = $TweakId
        Timestamp      = $timestamp
        Description    = $Description
        RegistryPath   = $RegistryPath
        ValueName      = $ValueName
        KeyExisted     = $keyExists
        ValueExisted   = $valueExists
        OriginalValue  = $originalValue
        OriginalKind   = $originalKind
        AppliedAt      = (Get-Date).ToString("o")
    }

    $snapshotJson = $snapshotData | ConvertTo-Json -Depth 5
    $snapshotJson | Set-Content -Path $snapshotFile -Encoding utf8

    Write-Verbose "Snapshot successfully created: $snapshotFile"
    return [PSCustomObject]@{
        Success      = $true
        SnapshotFile = $snapshotFile
        SnapshotData = $snapshotData
    }
}

function Restore-RegistrySnapshot {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SnapshotFilePath
    )

    if (-not (Test-Path $SnapshotFilePath)) {
        throw "Snapshot file not found: $SnapshotFilePath"
    }

    $data = Get-Content -Path $SnapshotFilePath -Raw -Encoding utf8 | ConvertFrom-Json
    $path = $data.RegistryPath
    $valName = $data.ValueName

    Write-Host "Restoring snapshot for [$($data.TweakId)] from $SnapshotFilePath..." -ForegroundColor Cyan

    if (-not $data.KeyExisted) {
        # The key was created by the tweak -> remove it if empty or present
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Removed newly created key: $path" -ForegroundColor Green
        }
        return $true
    }

    if ($valName) {
        if (-not $data.ValueExisted) {
            # The value didn't exist -> remove newly created value
            if (Test-Path $path) {
                Remove-ItemProperty -Path $path -Name $valName -ErrorAction SilentlyContinue
                Write-Host "Removed newly created value: $valName from $path" -ForegroundColor Green
            }
        } else {
            # Restore original value and type
            if (-not (Test-Path $path)) {
                New-Item -Path $path -Force | Out-Null
            }
            $kind = $data.OriginalKind
            $val = $data.OriginalValue

            if ($kind -eq "DWord") {
                Set-ItemProperty -Path $path -Name $valName -Value ([int]$val) -Type DWord -Force
            } elseif ($kind -eq "QWord") {
                Set-ItemProperty -Path $path -Name $valName -Value ([int64]$val) -Type QWord -Force
            } elseif ($kind -eq "Binary") {
                Set-ItemProperty -Path $path -Name $valName -Value ([byte[]]$val) -Type Binary -Force
            } else {
                Set-ItemProperty -Path $path -Name $valName -Value $val -Type String -Force
            }
            Write-Host "Restored original value: $valName = $val ($kind) in $path" -ForegroundColor Green
        }
    }

    return $true
}

function Get-RegistrySnapshots {
    [CmdletBinding()]
    param()

    $backupDir = Get-BackupStorageDir
    $files = Get-ChildItem -Path $backupDir -Filter "snapshot_*.json" | Sort-Object CreationTime -Descending
    $snapshots = @()
    foreach ($f in $files) {
        try {
            $data = Get-Content -Path $f.FullName -Raw -Encoding utf8 | ConvertFrom-Json
            $snapshots += [PSCustomObject]@{
                File        = $f.FullName
                TweakId     = $data.TweakId
                Timestamp   = $data.Timestamp
                Path        = $data.RegistryPath
                ValueName   = $data.ValueName
                Description = $data.Description
            }
        } catch {}
    }
    return $snapshots
}

if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function New-RegistrySnapshot, Restore-RegistrySnapshot, Get-RegistrySnapshots -ErrorAction SilentlyContinue
}
