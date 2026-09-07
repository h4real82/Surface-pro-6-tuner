<#
.SYNOPSIS
    Automated test for TidyUp-Manager module
#>

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $projectRoot "src\engine\TidyUp-Manager.ps1")

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Testing Tidy Up & Clean Engine                           " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Test 1: App Catalog Verification
Write-Host "[TIDY 1] Checking App Catalog..." -NoNewline
$catalog = Get-DebloatAppCatalog
if ($catalog.Count -ge 10) {
    Write-Host " [PASS] ($($catalog.Count) curated apps defined)" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "Curated app catalog has insufficient items."
}

# Test 2: Installed Apps Discovery
Write-Host "[TIDY 2] Querying installed bloatware apps..." -NoNewline
$installed = Get-InstalledDebloatApps
if ($installed.Count -ge 10) {
    $detected = ($installed | Where-Object { $_.IsInstalled }).Count
    Write-Host " [PASS] ($detected installed debloat targets found out of $($installed.Count))" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "Get-InstalledDebloatApps returned invalid result."
}

# Test 3: Disk Cleanup Inventory Level 1
Write-Host "[TIDY 3] Calculating Disk Cleanup Inventory Level 1..." -NoNewline
$inv1 = Get-DiskCleanupInventory -SafetyLevel 1
if ($null -ne $inv1 -and $inv1.Categories.Count -gt 0) {
    Write-Host " [PASS] (Level 1: $($inv1.TotalFormatted) detected across $($inv1.Categories.Count) categories)" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "Get-DiskCleanupInventory Level 1 failed."
}

# Test 4: Disk Cleanup Inventory Level 2
Write-Host "[TIDY 4] Calculating Disk Cleanup Inventory Level 2..." -NoNewline
$inv2 = Get-DiskCleanupInventory -SafetyLevel 2
if ($null -ne $inv2 -and $inv2.Categories.Count -ge $inv1.Categories.Count) {
    Write-Host " [PASS] (Level 2: $($inv2.TotalFormatted) detected across $($inv2.Categories.Count) categories)" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "Get-DiskCleanupInventory Level 2 failed."
}

# Test 5: Disk Cleanup DryRun
Write-Host "[TIDY 5] Running DryRun cleanup Level 1..." -NoNewline
$dryResult = Invoke-DiskCleanupTier -SafetyLevel 1 -DryRun
if ($null -ne $dryResult -and $dryResult.DryRun -eq $true) {
    Write-Host " [PASS] (DryRun simulated: $($dryResult.DeletedFiles) files, $($dryResult.FreedFormatted))" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "Invoke-DiskCleanupTier DryRun failed."
}

# Test 6: Protected App Safeguard Check
Write-Host "[TIDY 6] Testing Whitelist protection on critical app..." -NoNewline
$blocked = $false
try {
    Uninstall-DebloatApp -AppId "Microsoft.WindowsStore"
} catch {
    $blocked = $true
}
if ($blocked) {
    Write-Host " [PASS] (Windows Store uninstall safely blocked)" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "Critical app was not blocked from uninstall!"
}

Write-Host "`nTidy Up Engine Tests Passed Successfully!" -ForegroundColor Cyan
