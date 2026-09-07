<#
.SYNOPSIS
    Automated test for System-Scanner module
#>

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $projectRoot "src\engine\System-Scanner.ps1")

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Testing System Health & Optimization Scanner Engine      " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Test 1: Get-SystemOptimizationStatus
Write-Host "[SCAN 1] Running Get-SystemOptimizationStatus..." -NoNewline
$status = Get-SystemOptimizationStatus
if ($null -ne $status -and $status.ScorePercent -ge 0 -and $status.Items.Count -gt 0) {
    Write-Host " [PASS] (Score: $($status.ScorePercent)%, Total Items: $($status.Items.Count), Optimized: $($status.OptimizedCount))" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "Get-SystemOptimizationStatus returned invalid data."
}

# Test 2: Audit items structure check
Write-Host "[SCAN 2] Verifying item schema..." -NoNewline
$sample = $status.Items[0]
if ($sample.Id -and $sample.Description -and $null -ne $sample.IsOptimized) {
    Write-Host " [PASS] (Schema valid: Id, Description, IsOptimized)" -ForegroundColor Green
} else {
    Write-Host " [FAIL]" -ForegroundColor Red
    throw "Audit item missing required properties."
}

Write-Host "`nSystem Scanner Engine Tests Passed Successfully!" -ForegroundColor Cyan
