<#
.SYNOPSIS
    WPF GUI Controller for Surface Pro 6 Tuner
.DESCRIPTION
    Launches the modern desktop GUI application, binds UI buttons to tuning engines,
    manages rollback history and live thermal monitoring.
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$scriptRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $scriptRoot "hardware\Thermal-Manager.ps1")
. (Join-Path $scriptRoot "engine\Job-Runner.ps1")
. (Join-Path $scriptRoot "safety\Backup-Manager.ps1")

# Load XAML
$xamlPath = Join-Path $PSScriptRoot "MainWindow.xaml"
$xamlContent = Get-Content -Path $xamlPath -Raw -Encoding utf8
$stringReader = New-Object System.IO.StringReader($xamlContent)
$xmlReader = [System.Xml.XmlReader]::Create($stringReader)
$window = [System.Windows.Markup.XamlReader]::Load($xmlReader)

# UI Elements
$txtDeviceInfo = $window.FindName("TxtDeviceInfo")
$txtThermalStatus = $window.FindName("TxtThermalStatus")
$badgeThermal = $window.FindName("BadgeThermal")

$btnApplyPerf = $window.FindName("BtnApplyPerformance")
$btnApplyBat = $window.FindName("BtnApplyBattery")
$btnApplyTherm = $window.FindName("BtnApplyThermal")
$btnApplyAll = $window.FindName("BtnApplyAll")

$cmbSnapshots = $window.FindName("CmbSnapshots")
$btnRollbackSelected = $window.FindName("BtnRollbackSelected")
$btnRollbackLatest = $window.FindName("BtnRollbackLatest")
$txtLog = $window.FindName("TxtLog")

function Log-Ui([string]$message) {
    $time = (Get-Date).ToString("HH:mm:ss")
    $line = "[$time] $message`r`n"
    $txtLog.AppendText($line)
    $txtLog.ScrollToEnd()
}

function Refresh-SnapshotsList {
    $cmbSnapshots.Items.Clear()
    $snapshots = Get-RegistrySnapshots
    if ($snapshots.Count -eq 0) {
        $cmbSnapshots.Items.Add("Keine Snapshots vorhanden") | Out-Null
        $cmbSnapshots.SelectedIndex = 0
    } else {
        foreach ($s in $snapshots) {
            $itemText = "$($s.Timestamp) - $($s.TweakId): $($s.Description)"
            $cmbSnapshots.Items.Add($itemText) | Out-Null
        }
        $cmbSnapshots.SelectedIndex = 0
    }
}

function Refresh-HardwareInfo {
    try {
        $hw = Get-SurfaceHardwareInfo
        $txtDeviceInfo.Text = "$($hw.Manufacturer) $($hw.Model) | $($hw.ProcessorName) @ $($hw.CurrentClock) MHz"

        $th = Test-ProchotThrottling
        if ($th.IsSeverelyThrottled) {
            $txtThermalStatus.Text = "Thermal Status: THROTTLED ($($th.CurrentClockSpeedMHz) MHz)"
            $badgeThermal.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#7f1d1d")
            $txtThermalStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#f87171")
        } else {
            $txtThermalStatus.Text = "Thermal Status: Normal ($($th.CurrentClockSpeedMHz) MHz)"
            $badgeThermal.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#14532d")
            $txtThermalStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4ade80")
        }
    } catch {
        Log-Ui "Fehler beim Auslesen des Hardware-Status: $_"
    }
}

function Execute-ProfileFromUi([string]$profileId, [string]$profileName) {
    Log-Ui "=== Starte Optimierung: $profileName ==="
    try {
        $results = Invoke-SurfaceTuningJob -ProfileId $profileId -AutoAccept -Headless:$false

        foreach ($r in $results) {
            if ($r.Status -eq "SUCCESS") {
                Log-Ui "✅ $($r.TweakId): Erfolgreich angewendet. (Snapshot: $($r.Snapshot))"
            } elseif ($r.Status -eq "SKIPPED_ALREADY_APPLIED") {
                Log-Ui "ℹ️ $($r.TweakId): Bereits aktiv (Wert: $($r.CurrentVal))."
            } elseif ($r.Status -eq "BLOCKED") {
                Log-Ui "🛑 $($r.TweakId): VOM SAFETY GATE BLOCKIERT ($($r.Reason))."
            } else {
                Log-Ui "⚠️ $($r.TweakId): Status $($r.Status)."
            }
        }
        Log-Ui "=== Profil $profileName abgeschlossen ===`r`n"
        Refresh-SnapshotsList
        Refresh-HardwareInfo
    } catch {
        Log-Ui "❌ Schwerwiegender Fehler: $_"
    }
}

# Attach Button Events
$btnApplyPerf.Add_Click({
    Execute-ProfileFromUi -profileId "SurfacePerformance" -profileName "Performance Optimizer"
})

$btnApplyBat.Add_Click({
    Execute-ProfileFromUi -profileId "SurfaceBattery" -profileName "Akku & Standby Optimizer"
})

$btnApplyTherm.Add_Click({
    Execute-ProfileFromUi -profileId "ThermalUnlock" -profileName "Thermal Unthrottle"
})

$btnApplyAll.Add_Click({
    Execute-ProfileFromUi -profileId "All" -profileName "Komplett-Tuning (All-in-One)"
})

$btnRollbackLatest.Add_Click({
    $snapshots = Get-RegistrySnapshots
    if ($snapshots.Count -eq 0) {
        Log-Ui "Keine Snapshots zum Rückgängig machen vorhanden."
        return
    }
    $latest = $snapshots[0]
    Log-Ui "Rückgängig machen von letztem Snapshot: $($latest.TweakId)..."
    try {
        Restore-RegistrySnapshot -SnapshotFilePath $latest.File
        Log-Ui "✅ Erfolgreich rückgängig gemacht: $($latest.TweakId) -> Originalzustand wiederhergestellt."
        Refresh-SnapshotsList
    } catch {
        Log-Ui "❌ Fehler beim Rollback: $_"
    }
})

$btnRollbackSelected.Add_Click({
    $idx = $cmbSnapshots.SelectedIndex
    $snapshots = Get-RegistrySnapshots
    if ($idx -lt 0 -or $idx -ge $snapshots.Count) {
        Log-Ui "Ungültige Auswahl für Rollback."
        return
    }
    $chosen = $snapshots[$idx]
    Log-Ui "Rückgängig machen von Snapshot: $($chosen.TweakId)..."
    try {
        Restore-RegistrySnapshot -SnapshotFilePath $chosen.File
        Log-Ui "✅ Erfolgreich rückgängig gemacht: $($chosen.TweakId) -> Originalzustand wiederhergestellt."
        Refresh-SnapshotsList
    } catch {
        Log-Ui "❌ Fehler beim Rollback: $_"
    }
})

# Initial Startup
Refresh-HardwareInfo
Refresh-SnapshotsList
Log-Ui "Surface Pro 6 Tuner bereit. Wähle eine Aktion aus."

# Show Window
$window.ShowDialog() | Out-Null
