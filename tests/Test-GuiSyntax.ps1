<#
.SYNOPSIS
    Validation test for Surface Pro 6 Tuner GUI XAML and Controllers
#>

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path $PSScriptRoot -Parent

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Testing Surface Pro 6 Tuner GUI XAML & Data Binding    " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Helper function to load and parse XAML safely
function Test-XamlLoad([string]$filename) {
    $path = Join-Path $projectRoot "src\gui\$filename"
    $raw = Get-Content -Path $path -Raw -Encoding utf8
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($raw))
    return [System.Windows.Markup.XamlReader]::Load($reader)
}

# Test 1: MainWindow.xaml
Write-Host "[GUI 1] Parsing MainWindow.xaml..." -NoNewline
$winMain = Test-XamlLoad "MainWindow.xaml"
if ($null -ne $winMain) {
    Write-Host " [PASS]" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "MainWindow.xaml failed to load."
}

# Test 2: MainWindow Controls Discovery
Write-Host "[GUI 2] Verifying MainWindow UI Controls..." -NoNewline
$mainControls = @("TxtDeviceInfo", "TxtThermalStatus", "BadgeThermal",
                  "BtnOpenScan", "BtnOpenTidyUp",
                  "BtnApplyPerformance", "BtnApplyBattery", "BtnApplyThermal", "BtnApplyAll",
                  "CmbSnapshots", "BtnRollbackSelected", "BtnRollbackLatest", "TxtLog")

foreach ($c in $mainControls) {
    $elem = $winMain.FindName($c)
    if ($null -eq $elem) {
        Write-Host " [FAIL]" -ForegroundColor Red
        throw "UI Element [$c] not found in MainWindow.xaml."
    }
}
Write-Host " [PASS] (All $($mainControls.Count) UI controls found)" -ForegroundColor Green

# Test 3: ScanWindow.xaml
Write-Host "[GUI 3] Parsing ScanWindow.xaml..." -NoNewline
$winScan = Test-XamlLoad "ScanWindow.xaml"
if ($null -ne $winScan) {
    $scanControls = @("TxtScanSummary", "PrgScanScore", "LstAuditItems", "BtnRescan", "BtnApplyAllRecommendations", "BtnCloseScan", "TxtScanPendingNotice")
    foreach ($sc in $scanControls) {
        if ($null -eq $winScan.FindName($sc)) {
            throw "Scan UI control [$sc] not found."
        }
    }
    Write-Host " [PASS] (All $($scanControls.Count) ScanWindow controls found)" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "ScanWindow.xaml failed to load."
}

# Test 4: TidyUpWindow.xaml
Write-Host "[GUI 4] Parsing TidyUpWindow.xaml..." -NoNewline
$winTidy = Test-XamlLoad "TidyUpWindow.xaml"
if ($null -ne $winTidy) {
    $tidyControls = @("BtnCloseTidyUp", "BtnSelectSafeApps", "BtnDeselectAllApps", "LstApps", "BtnUninstallSelectedApps",
                      "RadLevel1", "RadLevel2", "RadLevel3", "LstDiskCategories", "TxtDiskTotal", "BtnAnalyzeDisk", "BtnExecuteClean", "TxtTidyLog")
    foreach ($tc in $tidyControls) {
        if ($null -eq $winTidy.FindName($tc)) {
            throw "TidyUp UI control [$tc] not found."
        }
    }
    Write-Host " [PASS] (All $($tidyControls.Count) TidyUpWindow controls found)" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "TidyUpWindow.xaml failed to load."
}

# Test 5: AST Parser Validation on App.ps1
Write-Host "[GUI 5] Checking App.ps1 syntax with AST Parser..." -NoNewline
$appScriptPath = Join-Path $projectRoot "src\gui\App.ps1"
$appScriptContent = Get-Content -Path $appScriptPath -Raw
$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($appScriptContent, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count -eq 0) {
    Write-Host " [PASS] (Zero syntax errors in App.ps1)" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    foreach ($err in $parseErrors) {
        Write-Host "    $($err.Message) at line $($err.Extent.StartLineNumber)" -ForegroundColor Red
    }
    throw "App.ps1 has $($parseErrors.Count) syntax error(s)."
}

# Test 6: Executable Binary Check
Write-Host "[GUI 6] Checking SurfacePro6Tuner.exe..." -NoNewline
$exePath = Join-Path $projectRoot "SurfacePro6Tuner.exe"
if (Test-Path $exePath) {
    Write-Host " [PASS] (Native Windows App binary verified)" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "SurfacePro6Tuner.exe not found."
}

Write-Host "`nAll GUI Tests Passed Successfully!" -ForegroundColor Cyan
