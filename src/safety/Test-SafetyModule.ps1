<#
.SYNOPSIS
    Unit and Integration Tests for Surface Pro 6 Tuner Safety Module
#>

param()

$ErrorActionPreference = "Stop"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host " Running Safety Module Tests for Surface Pro 6   " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

. (Join-Path $PSScriptRoot "Registry-Validator.ps1")
. (Join-Path $PSScriptRoot "Backup-Manager.ps1")

# Test 1: Config Loading
Write-Host "`n[Test 1] Loading Surface-AllowList.json..." -NoNewline
$allowList = Get-SurfaceAllowList
if ($allowList.device -eq "Microsoft Surface Pro 6 (1796)") {
    Write-Host " [PASS]" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "AllowList device header mismatch."
}

# Test 2: Blocking Critical Touch Path
Write-Host "[Test 2] Protecting Surface Touch Hardware Path..." -NoNewline
$touchCheck = Test-TweakSafety -RegistryPath "HKLM:\SYSTEM\CurrentControlSet\Services\SurfaceTouchServicingKernel" -ValueName "Start"
if (-not $touchCheck.IsSafe -and $touchCheck.Severity -eq "CRITICAL_BLOCKED") {
    Write-Host " [PASS] (Blocked as expected: $($touchCheck.Reason))" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "Touch hardware path was NOT blocked!"
}

# Test 3: Blocking DPTF Thermal Throttling Subsystem
Write-Host "[Test 3] Protecting Intel DPTF Subsystem..." -NoNewline
$dptfCheck = Test-TweakSafety -RegistryPath "HKLM:\SYSTEM\CurrentControlSet\Services\dptf_cpu" -ValueName "Start"
if (-not $dptfCheck.IsSafe -and $dptfCheck.Severity -eq "CRITICAL_BLOCKED") {
    Write-Host " [PASS] (Blocked as expected)" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "DPTF path was NOT blocked!"
}

# Test 4: Blocking Protected Modern Standby Value
Write-Host "[Test 4] Protecting CsEnabled..." -NoNewline
$csCheck = Test-TweakSafety -RegistryPath "HKLM:\SYSTEM\CurrentControlSet\Control\Power" -ValueName "CsEnabled"
if (-not $csCheck.IsSafe -and $csCheck.Severity -eq "CRITICAL_BLOCKED") {
    Write-Host " [PASS] (Blocked as expected)" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "CsEnabled was NOT blocked!"
}

# Test 5: Approving Valid Scope (DataCollection)
Write-Host "[Test 5] Approving Allowed Telemetry Scope..." -NoNewline
$telemetryCheck = Test-TweakSafety -RegistryPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -ValueName "AllowTelemetry"
if ($telemetryCheck.IsSafe -and $telemetryCheck.Severity -eq "SAFE") {
    Write-Host " [PASS]" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "Valid Telemetry scope was unexpectedly blocked!"
}

# Test 6: Snapshot Creation & Validation Integration
Write-Host "[Test 6] Snapshot Creation for Approved Scope..." -NoNewline
$snapResult = New-RegistrySnapshot -TweakId "TestTelemetry" `
    -RegistryPath "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" `
    -ValueName "AllowTelemetry" `
    -Description "Unit Test Snapshot"

if ($snapResult.Success -and (Test-Path $snapResult.SnapshotFile)) {
    Write-Host " [PASS] (Created: $(Split-Path $snapResult.SnapshotFile -Leaf))" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "Snapshot file could not be verified."
}

# Clean up unit test snapshot
Remove-Item -Path $snapResult.SnapshotFile -Force -ErrorAction SilentlyContinue

Write-Host "`nAll 6 Safety Gate Tests Passed Successfully!" -ForegroundColor Cyan
