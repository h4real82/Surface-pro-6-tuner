@echo off
:: Surface Pro 6 Tuner - 1-Click Elevated Launcher
:: Automatically requests Administrator privileges if required

:: Check for administrative rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [Surface Pro 6 Tuner] Administratorrechte erforderlich.
    echo Fordere UAC-Bestaetigung an...
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)

:: Elevated session running
cd /d "%~dp0"
title Surface Pro 6 Tuner

echo ======================================================================
echo           Microsoft Surface Pro 6 Tuner ^& Optimizer
echo ======================================================================
echo [1] Alles optimieren (Performance + Battery + Thermal) - AutoAccept
echo [2] Nur Performance & Telemetrie-Entlastung
echo [3] Nur Akku & Modern Standby Optimierung
echo [4] Hardware & Thermal-Status pruefen
echo [5] Dry-Run Simulation (Nur pruefen, keine Aenderungen)
echo [6] Rollback / Letztes Snapshot wiederherstellen
echo [0] Beenden
echo ======================================================================
set /p opt="Waehle eine Option (Standard: 1): "

if "%opt%"=="" set opt=1
if "%opt%"=="0" exit /b
if "%opt%"=="1" goto Opt1
if "%opt%"=="2" goto Opt2
if "%opt%"=="3" goto Opt3
if "%opt%"=="4" goto Opt4
if "%opt%"=="5" goto Opt5
if "%opt%"=="6" goto Opt6

:Opt1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SurfaceTuner.ps1" -Profile All -AutoAccept
goto End

:Opt2
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SurfaceTuner.ps1" -Profile SurfacePerformance -AutoAccept
goto End

:Opt3
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SurfaceTuner.ps1" -Profile SurfaceBattery -AutoAccept
goto End

:Opt4
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SurfaceTuner.ps1" -Status
goto End

:Opt5
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SurfaceTuner.ps1" -Profile All -DryRun
goto End

:Opt6
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0SurfaceTuner.ps1" -Rollback
goto End

:End
echo.
pause
