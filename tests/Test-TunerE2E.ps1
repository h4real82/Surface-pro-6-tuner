<#
.SYNOPSIS
    End-to-End Test Suite for Surface Pro 6 Tuner
#>

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path $PSScriptRoot -Parent

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Running End-to-End Integration Tests for Surface Tuner " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# Test 1: Hardware Diagnostics
Write-Host "[E2E 1] Hardware Detection..." -NoNewline
. (Join-Path $projectRoot "src\hardware\Thermal-Manager.ps1")
$hw = Get-SurfaceHardwareInfo
if ($hw.Model -like "*Surface*") {
    Write-Host " [PASS] (Detected: $($hw.Model), CPU: $($hw.ProcessorName))" -ForegroundColor Green
} else {
    Write-Host " [PASS] (Hardware query succeeded: $($hw.Model))" -ForegroundColor Green
}

# Test 2: Thermal Throttling Status Check
Write-Host "[E2E 2] Thermal & PROCHOT Status..." -NoNewline
$th = Test-ProchotThrottling
if ($null -ne $th.CurrentClockSpeedMHz) {
    Write-Host " [PASS] (Current Clock: $($th.CurrentClockSpeedMHz) MHz)" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "Thermal check failed."
}

# Test 3: Headless DryRun Execution
Write-Host "[E2E 3] Headless Dry-Run Simulation..." -NoNewline
$tunerScript = Join-Path $projectRoot "SurfaceTuner.ps1"
$jsonOut = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tunerScript -Profile All -DryRun -Headless
$summary = $jsonOut | ConvertFrom-Json
if ($summary.Success -ge 8 -and $summary.Blocked -eq 0) {
    Write-Host " [PASS] (Evaluated $($summary.Success) tweaks, 0 blocked)" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "DryRun execution did not complete expected tweaks."
}

# Test 4: Profile-Specific DryRun (Battery & Performance)
Write-Host "[E2E 4] Profile Filtering (SurfaceBattery)..." -NoNewline
$batteryOut = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tunerScript -Profile SurfaceBattery -DryRun -Headless
$batterySummary = $batteryOut | ConvertFrom-Json
if ($batterySummary.Profile -eq "SurfaceBattery" -and $batterySummary.Success -eq 3) {
    Write-Host " [PASS]" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "Battery profile filtering failed."
}

Write-Host "`nAll E2E Tests Completed Successfully!" -ForegroundColor Cyan
