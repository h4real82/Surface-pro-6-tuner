<#
.SYNOPSIS
    Registry Validator for Surface Pro 6 Tuner
.DESCRIPTION
    Validates proposed registry operations against Surface-specific hardware protection
    rules and safe tweak scopes to prevent breaking Touch, DPTF, Sensors, or Modern Standby.
#>

function Get-SurfaceAllowList {
    [CmdletBinding()]
    param (
        [string]$ConfigPath = (Join-Path $PSScriptRoot "Surface-AllowList.json")
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Surface-AllowList configuration file not found at: $ConfigPath"
    }

    $raw = Get-Content -Path $ConfigPath -Raw -Encoding utf8
    return ($raw | ConvertFrom-Json)
}

function Test-TweakSafety {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RegistryPath,

        [Parameter(Mandatory = $false)]
        [string]$ValueName = "",

        [Parameter(Mandatory = $false)]
        [object]$AllowList = $null
    )

    if ($null -eq $AllowList) {
        $AllowList = Get-SurfaceAllowList
    }

    # Normalize path (remove trailing slashes, standardize HKLM/HKCU)
    $normPath = $RegistryPath.TrimEnd('\')
    if ($normPath -match "^HKEY_LOCAL_MACHINE\\(.*)$") { $normPath = "HKLM:\$($Matches[1])" }
    if ($normPath -match "^HKEY_CURRENT_USER\\(.*)$") { $normPath = "HKCU:\$($Matches[1])" }

    $result = [PSCustomObject]@{
        IsSafe       = $false
        RegistryPath = $normPath
        ValueName    = $ValueName
        Severity     = "BLOCKED"
        Reason       = ""
    }

    # Check 1: Protected Hardware Paths (Critical Surface subsystems)
    foreach ($pattern in $AllowList.protectedPaths) {
        if ($normPath -like $pattern) {
            $result.IsSafe = $false
            $result.Severity = "CRITICAL_BLOCKED"
            $result.Reason = "Path matches protected hardware rule [$pattern]. Surface Pro 6 Touch, Thermal or Sensor subsystem would be affected."
            return $result
        }
    }

    # Check 2: Protected Value Names (e.g. CsEnabled, PlatformAoAcOverride)
    if ($ValueName -and ($AllowList.protectedValues -contains $ValueName)) {
        $result.IsSafe = $false
        $result.Severity = "CRITICAL_BLOCKED"
        $result.Reason = "Value [$ValueName] is explicitly protected against modification on Surface Pro 6."
        return $result
    }

    # Check 3: Check against Allowed Tweak Scopes
    $isUnderAllowedScope = $false
    foreach ($scope in $AllowList.allowedTweakScopes) {
        $normScope = $scope.TrimEnd('\')
        if ($normPath.StartsWith($normScope, [System.StringComparison]::OrdinalIgnoreCase)) {
            $isUnderAllowedScope = $true
            break
        }
    }

    if ($isUnderAllowedScope) {
        $result.IsSafe = $true
        $result.Severity = "SAFE"
        $result.Reason = "Path is within an approved safe tweak scope."
        return $result
    }

    # Check 4: Path outside defined scopes (Warning)
    $result.IsSafe = $false
    $result.Severity = "UNAPPROVED_SCOPE"
    $result.Reason = "Path is not explicitly in allowedTweakScopes. Manual verification required."
    return $result
}

if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function Get-SurfaceAllowList, Test-TweakSafety -ErrorAction SilentlyContinue
}
