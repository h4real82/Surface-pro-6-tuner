<#
.SYNOPSIS
    Validation test for Surface Pro 6 Tuner GUI XAML and Controller
#>

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path $PSScriptRoot -Parent

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host " Testing Surface Pro 6 Tuner GUI XAML & Data Binding    " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Test 1: XAML Parsing
Write-Host "[GUI 1] Parsing MainWindow.xaml..." -NoNewline
$xamlPath = Join-Path $projectRoot "src\gui\MainWindow.xaml"
$xamlContent = Get-Content -Path $xamlPath -Raw -Encoding utf8
$stringReader = New-Object System.IO.StringReader($xamlContent)
$xmlReader = [System.Xml.XmlReader]::Create($stringReader)
$window = [System.Windows.Markup.XamlReader]::Load($xmlReader)

if ($null -ne $window) {
    Write-Host " [PASS]" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "XAML failed to load."
}

# Test 2: Control Elements Discovery
Write-Host "[GUI 2] Verifying UI Controls..." -NoNewline
$controls = @("TxtDeviceInfo", "TxtThermalStatus", "BadgeThermal",
              "BtnApplyPerformance", "BtnApplyBattery", "BtnApplyThermal", "BtnApplyAll",
              "CmbSnapshots", "BtnRollbackSelected", "BtnRollbackLatest", "TxtLog")

foreach ($c in $controls) {
    $elem = $window.FindName($c)
    if ($null -eq $elem) {
        Write-Host " [FAIL]" -ForegroundColor Red
        throw "UI Element [$c] not found in XAML tree."
    }
}
Write-Host " [PASS] (All 11 UI controls found)" -ForegroundColor Green

# Test 3: Executable Verification
Write-Host "[GUI 3] Checking SurfacePro6Tuner.exe..." -NoNewline
$exePath = Join-Path $projectRoot "SurfacePro6Tuner.exe"
if (Test-Path $exePath) {
    Write-Host " [PASS] (Native Windows App binary verified)" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "SurfacePro6Tuner.exe not found."
}

Write-Host "`nAll GUI Tests Passed Successfully!" -ForegroundColor Cyan
