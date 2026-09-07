<#
.SYNOPSIS
    WPF GUI Controller for Surface Pro 6 Tuner Suite
.DESCRIPTION
    Launches the modern desktop GUI application, binds UI buttons to tuning engines,
    manages rollback history, live thermal monitoring, system scan audit, and Tidy Up.
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$scriptRoot = Split-Path $PSScriptRoot -Parent
. (Join-Path $scriptRoot "hardware\Thermal-Manager.ps1")
. (Join-Path $scriptRoot "engine\Job-Runner.ps1")
. (Join-Path $scriptRoot "safety\Backup-Manager.ps1")
. (Join-Path $scriptRoot "engine\System-Scanner.ps1")
. (Join-Path $scriptRoot "engine\TidyUp-Manager.ps1")

# Load Main XAML
$xamlPath = Join-Path $PSScriptRoot "MainWindow.xaml"
$xamlContent = Get-Content -Path $xamlPath -Raw -Encoding utf8
$stringReader = New-Object System.IO.StringReader($xamlContent)
$xmlReader = [System.Xml.XmlReader]::Create($stringReader)
$window = [System.Windows.Markup.XamlReader]::Load($xmlReader)

# UI Elements - Main Window
$txtDeviceInfo = $window.FindName("TxtDeviceInfo")
$txtThermalStatus = $window.FindName("TxtThermalStatus")
$badgeThermal = $window.FindName("BadgeThermal")

$btnOpenScan = $window.FindName("BtnOpenScan")
$btnOpenTidyUp = $window.FindName("BtnOpenTidyUp")

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
                Log-Ui "[ERFOLG] $($r.TweakId): Erfolgreich angewendet. (Snapshot: $($r.Snapshot))"
            } elseif ($r.Status -eq "SKIPPED_ALREADY_APPLIED") {
                Log-Ui "[INFO] $($r.TweakId): Bereits aktiv (Wert: $($r.CurrentVal))."
            } elseif ($r.Status -eq "BLOCKED") {
                Log-Ui "[BLOCKIERT] $($r.TweakId): VOM SAFETY GATE BLOCKIERT ($($r.Reason))."
            } else {
                Log-Ui "[STATUS] $($r.TweakId): Status $($r.Status)."
            }
        }
        Log-Ui "=== Profil $profileName abgeschlossen ===`r`n"
        Refresh-SnapshotsList
        Refresh-HardwareInfo
    } catch {
        Log-Ui "[FEHLER] Schwerwiegender Fehler: $_"
    }
}

# ==============================================================================
# SYSTEM SCAN MODAL CONTROLLER
# ==============================================================================
function Show-ScanDialog {
    $scanXamlPath = Join-Path $PSScriptRoot "ScanWindow.xaml"
    $scanContent = Get-Content -Path $scanXamlPath -Raw -Encoding utf8
    $scanReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($scanContent))
    $scanWin = [System.Windows.Markup.XamlReader]::Load($scanReader)
    $scanWin.Owner = $window

    $txtScanSummary = $scanWin.FindName("TxtScanSummary")
    $prgScanScore = $scanWin.FindName("PrgScanScore")
    $lstAuditItems = $scanWin.FindName("LstAuditItems")
    $btnRescan = $scanWin.FindName("BtnRescan")
    $btnApplyAllRec = $scanWin.FindName("BtnApplyAllRecommendations")
    $btnCloseScan = $scanWin.FindName("BtnCloseScan")
    $txtPendingNotice = $scanWin.FindName("TxtScanPendingNotice")

    $loadAuditAction = {
        $lstAuditItems.Items.Clear()
        $status = Get-SystemOptimizationStatus
        $prgScanScore.Value = $status.ScorePercent
        $txtScanSummary.Text = "System-Score: $($status.ScorePercent)% Optimiert | $($status.OptimizedCount) von $($status.TotalItems) Einstellungen optimal."

        if ($status.PendingCount -gt 0) {
            $txtPendingNotice.Text = "$($status.PendingCount) Optimierung(en) verfuegbar."
            $btnApplyAllRec.IsEnabled = $true
        } else {
            $txtPendingNotice.Text = "Alles optimal konfiguriert!"
            $btnApplyAllRec.IsEnabled = $false
        }

        foreach ($item in $status.Items) {
            $card = New-Object System.Windows.Controls.Border
            $card.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#27272a")
            $card.CornerRadius = [System.Windows.CornerRadius]::new(8)
            $card.Padding = [System.Windows.Thickness]::new(12, 10, 12, 10)
            $card.Margin = [System.Windows.Thickness]::new(0, 0, 0, 6)
            $card.BorderThickness = [System.Windows.Thickness]::new(1)
            $card.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#3f3f46")

            $grid = New-Object System.Windows.Controls.Grid
            $c1 = New-Object System.Windows.Controls.ColumnDefinition
            $c1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
            $c2 = New-Object System.Windows.Controls.ColumnDefinition
            $c2.Width = [System.Windows.GridLength]::Auto
            $grid.ColumnDefinitions.Add($c1)
            $grid.ColumnDefinitions.Add($c2)

            $infoStack = New-Object System.Windows.Controls.StackPanel
            $infoStack.Orientation = [System.Windows.Controls.Orientation]::Vertical

            $topRow = New-Object System.Windows.Controls.StackPanel
            $topRow.Orientation = [System.Windows.Controls.Orientation]::Horizontal

            $title = New-Object System.Windows.Controls.TextBlock
            $title.Text = "$($item.Id)"
            $title.FontSize = 13
            $title.FontWeight = [System.Windows.FontWeights]::Bold
            $title.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#f4f4f5")
            $topRow.Children.Add($title) | Out-Null

            $catBadge = New-Object System.Windows.Controls.Border
            $catBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#334155")
            $catBadge.CornerRadius = [System.Windows.CornerRadius]::new(4)
            $catBadge.Padding = [System.Windows.Thickness]::new(6, 1, 6, 1)
            $catBadge.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
            $catTxt = New-Object System.Windows.Controls.TextBlock
            $catTxt.Text = "$($item.ProfileName)"
            $catTxt.FontSize = 10
            $catTxt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#94a3b8")
            $catBadge.Child = $catTxt
            $topRow.Children.Add($catBadge) | Out-Null
            $infoStack.Children.Add($topRow) | Out-Null

            $desc = New-Object System.Windows.Controls.TextBlock
            $desc.Text = "$($item.Description)"
            $desc.FontSize = 11
            $desc.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#a1a1aa")
            $desc.Margin = [System.Windows.Thickness]::new(0, 2, 0, 2)
            $infoStack.Children.Add($desc) | Out-Null

            $valTxt = New-Object System.Windows.Controls.TextBlock
            $valTxt.Text = "Aktueller Wert: $($item.CurrentValue)  |  Empfohlen: $($item.TargetValue)"
            $valTxt.FontSize = 10
            $valTxt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#71717a")
            $infoStack.Children.Add($valTxt) | Out-Null

            [System.Windows.Controls.Grid]::SetColumn($infoStack, 0)
            $grid.Children.Add($infoStack) | Out-Null

            $actionStack = New-Object System.Windows.Controls.StackPanel
            $actionStack.Orientation = [System.Windows.Controls.Orientation]::Horizontal
            $actionStack.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

            $statusBadge = New-Object System.Windows.Controls.Border
            $statusBadge.CornerRadius = [System.Windows.CornerRadius]::new(6)
            $statusBadge.Padding = [System.Windows.Thickness]::new(8, 4, 8, 4)
            $badgeTxt = New-Object System.Windows.Controls.TextBlock
            $badgeTxt.FontSize = 11
            $badgeTxt.FontWeight = [System.Windows.FontWeights]::SemiBold

            if ($item.IsOptimized) {
                $statusBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#14532d")
                $badgeTxt.Text = "[OPTIMIERT]"
                $badgeTxt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4ade80")
            } else {
                $statusBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#78350f")
                $badgeTxt.Text = "[OFFEN]"
                $badgeTxt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#facc15")
            }
            $statusBadge.Child = $badgeTxt
            $actionStack.Children.Add($statusBadge) | Out-Null

            if (-not $item.IsOptimized -and $item.ProfileId -ne "HardwareHealth") {
                $fixBtn = New-Object System.Windows.Controls.Button
                $fixBtn.Content = "Anwenden"
                $fixBtn.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0284c7")
                $fixBtn.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#ffffff")
                $fixBtn.FontWeight = [System.Windows.FontWeights]::SemiBold
                $fixBtn.FontSize = 11
                $fixBtn.Padding = [System.Windows.Thickness]::new(10, 4, 10, 4)
                $fixBtn.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
                $fixBtn.Cursor = [System.Windows.Input.Cursors]::Hand
                $fixBtn.BorderThickness = [System.Windows.Thickness]::new(0)
                $tweakToFix = $item.Id
                $fixBtn.Add_Click({
                    try {
                        Invoke-SystemTweakFix -TweakId $tweakToFix | Out-Null
                        Log-Ui "[SCAN] Tweak [$tweakToFix] erfolgreich ueber Scan-Modul angewendet."
                        Refresh-SnapshotsList
                        Refresh-HardwareInfo
                        & $loadAuditAction
                    } catch {
                        Log-Ui "[FEHLER] Konnte [$tweakToFix] nicht anwenden: $_"
                    }
                }.GetNewClosure())
                $actionStack.Children.Add($fixBtn) | Out-Null
            }

            [System.Windows.Controls.Grid]::SetColumn($actionStack, 1)
            $grid.Children.Add($actionStack) | Out-Null

            $card.Child = $grid
            $lstAuditItems.Items.Add($card) | Out-Null
        }
    }

    $btnRescan.Add_Click({
        & $loadAuditAction
    })

    $btnApplyAllRec.Add_Click({
        Log-Ui "=== Wende alle ausstehenden Scan-Empfehlungen an ==="
        Execute-ProfileFromUi -profileId "All" -profileName "Alle Scan-Empfehlungen"
        & $loadAuditAction
    })

    $btnCloseScan.Add_Click({
        $scanWin.Close()
    })

    & $loadAuditAction
    $scanWin.ShowDialog() | Out-Null
}

# ==============================================================================
# TIDY UP MODAL CONTROLLER (APPS & 3-TIER DISK CLEANUP)
# ==============================================================================
function Show-TidyUpDialog {
    $tidyXamlPath = Join-Path $PSScriptRoot "TidyUpWindow.xaml"
    $tidyContent = Get-Content -Path $tidyXamlPath -Raw -Encoding utf8
    $tidyReader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($tidyContent))
    $tidyWin = [System.Windows.Markup.XamlReader]::Load($tidyReader)
    $tidyWin.Owner = $window

    $lstApps = $tidyWin.FindName("LstApps")
    $btnSelectSafeApps = $tidyWin.FindName("BtnSelectSafeApps")
    $btnDeselectAllApps = $tidyWin.FindName("BtnDeselectAllApps")
    $btnUninstallSelectedApps = $tidyWin.FindName("BtnUninstallSelectedApps")

    $radLevel1 = $tidyWin.FindName("RadLevel1")
    $radLevel2 = $tidyWin.FindName("RadLevel2")
    $radLevel3 = $tidyWin.FindName("RadLevel3")
    $lstDiskCategories = $tidyWin.FindName("LstDiskCategories")
    $txtDiskTotal = $tidyWin.FindName("TxtDiskTotal")
    $btnAnalyzeDisk = $tidyWin.FindName("BtnAnalyzeDisk")
    $btnExecuteClean = $tidyWin.FindName("BtnExecuteClean")
    $btnCloseTidyUp = $tidyWin.FindName("BtnCloseTidyUp")
    $txtTidyLog = $tidyWin.FindName("TxtTidyLog")

    $appCheckboxes = @{}

    function Log-Tidy([string]$msg) {
        $t = (Get-Date).ToString("HH:mm:ss")
        $txtTidyLog.AppendText("[$t] $msg`r`n")
        $txtTidyLog.ScrollToEnd()
    }

    $refreshAppsList = {
        $lstApps.Items.Clear()
        $appCheckboxes.Clear()
        Log-Tidy "[APPS] Ermittle installierte UWP/Bloatware Apps..."
        $apps = Get-InstalledDebloatApps

        foreach ($app in $apps) {
            $border = New-Object System.Windows.Controls.Border
            $border.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#27272a")
            $border.CornerRadius = [System.Windows.CornerRadius]::new(6)
            $border.Padding = [System.Windows.Thickness]::new(10, 8, 10, 8)
            $border.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
            $border.BorderThickness = [System.Windows.Thickness]::new(1)
            $border.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#3f3f46")

            $grid = New-Object System.Windows.Controls.Grid
            $c1 = New-Object System.Windows.Controls.ColumnDefinition
            $c1.Width = [System.Windows.GridLength]::Auto
            $c2 = New-Object System.Windows.Controls.ColumnDefinition
            $c2.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
            $c3 = New-Object System.Windows.Controls.ColumnDefinition
            $c3.Width = [System.Windows.GridLength]::Auto
            $grid.ColumnDefinitions.Add($c1)
            $grid.ColumnDefinitions.Add($c2)
            $grid.ColumnDefinitions.Add($c3)

            $chk = New-Object System.Windows.Controls.CheckBox
            $chk.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $chk.Margin = [System.Windows.Thickness]::new(0, 0, 10, 0)
            $chk.IsEnabled = $app.IsInstalled
            $chk.Tag = $app.Id
            $appCheckboxes[$app.Id] = $chk
            [System.Windows.Controls.Grid]::SetColumn($chk, 0)
            $grid.Children.Add($chk) | Out-Null

            $info = New-Object System.Windows.Controls.StackPanel
            $nameTxt = New-Object System.Windows.Controls.TextBlock
            $nameTxt.Text = "$($app.DisplayName)"
            $nameTxt.FontSize = 13
            $nameTxt.FontWeight = [System.Windows.FontWeights]::SemiBold
            $nameTxt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#f4f4f5")
            $info.Children.Add($nameTxt) | Out-Null

            $descTxt = New-Object System.Windows.Controls.TextBlock
            $descTxt.Text = "$($app.Description) [Kategorie: $($app.Category)]"
            $descTxt.FontSize = 11
            $descTxt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#a1a1aa")
            $info.Children.Add($descTxt) | Out-Null
            [System.Windows.Controls.Grid]::SetColumn($info, 1)
            $grid.Children.Add($info) | Out-Null

            $badge = New-Object System.Windows.Controls.Border
            $badge.CornerRadius = [System.Windows.CornerRadius]::new(4)
            $badge.Padding = [System.Windows.Thickness]::new(8, 3, 8, 3)
            $badge.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $bt = New-Object System.Windows.Controls.TextBlock
            $bt.FontSize = 11
            $bt.FontWeight = [System.Windows.FontWeights]::SemiBold

            if ($app.IsInstalled) {
                $badge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#7f1d1d")
                $bt.Text = "Installiert"
                $bt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#f87171")
            } else {
                $badge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#14532d")
                $bt.Text = "Nicht vorhanden"
                $bt.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#4ade80")
            }
            $badge.Child = $bt
            [System.Windows.Controls.Grid]::SetColumn($badge, 2)
            $grid.Children.Add($badge) | Out-Null

            $border.Child = $grid
            $lstApps.Items.Add($border) | Out-Null
        }
        Log-Tidy "[APPS] $($apps.Count) definierte Bloatware-Ziele geladen."
    }

    $btnSelectSafeApps.Add_Click({
        $catalog = Get-DebloatAppCatalog
        $count = 0
        foreach ($c in $catalog) {
            if ($c.Safe -and $appCheckboxes.ContainsKey($c.Id)) {
                $cb = $appCheckboxes[$c.Id]
                if ($cb.IsEnabled) {
                    $cb.IsChecked = $true
                    $count++
                }
            }
        }
        Log-Tidy "[APPS] $count sichere vorinstallierte Apps ausgewaehlt."
    })

    $btnDeselectAllApps.Add_Click({
        foreach ($k in $appCheckboxes.Keys) {
            $appCheckboxes[$k].IsChecked = $false
        }
        Log-Tidy "[APPS] Alle Apps abgewaehlt."
    })

    $btnUninstallSelectedApps.Add_Click({
        $selectedIds = @()
        foreach ($k in $appCheckboxes.Keys) {
            if ($appCheckboxes[$k].IsChecked) {
                $selectedIds += $k
            }
        }

        if ($selectedIds.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Bitte mindestens eine installierte App zur Deinstallation auswaehlen.", "Keine Auswahl", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
            return
        }

        $confirm = [System.Windows.MessageBox]::Show("Moechtest du die $($selectedIds.Count) ausgewaehlten App(s) wirklich restlos deinstallieren? Dies entfernt sie fuer alle Benutzer und verhindert Neuinstallation bei Updates.", "Deinstallation bestaetigen", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
        if ($confirm -ne [System.Windows.MessageBoxResult]::Yes) {
            Log-Tidy "[APPS] Deinstallation durch Benutzer abgebrochen."
            return
        }

        Log-Tidy "=== Starte Deinstallation von $($selectedIds.Count) Apps ==="
        foreach ($id in $selectedIds) {
            try {
                Log-Tidy "[APPS] Deinstalliere $id..."
                $res = Uninstall-DebloatApp -AppId $id
                if ($res.Success) {
                    Log-Tidy "[ERFOLG] $id restlos entfernt ($($res.RemovedCount) Pakete bereinigt)."
                } else {
                    Log-Tidy "[WARNUNG] $id mit Hinweisen entfernt: $($res.Errors -join '; ')"
                }
            } catch {
                Log-Tidy "[FEHLER] $id konnte nicht entfernt werden: $_"
            }
        }
        Log-Tidy "=== App-Bereinigung abgeschlossen ===`r`n"
        & $refreshAppsList
    })

    # Disk Cleanup Logic
    function Get-SelectedSafetyLevel {
        if ($radLevel3.IsChecked) { return 3 }
        if ($radLevel2.IsChecked) { return 2 }
        return 1
    }

    $analyzeDiskAction = {
        $level = Get-SelectedSafetyLevel
        Log-Tidy "[SPEICHER] Analysiere Speicher- & Cache-Daten (Sicherheitsstufe $level)..."
        $inv = Get-DiskCleanupInventory -SafetyLevel $level
        $txtDiskTotal.Text = "Ermittelt: $($inv.TotalFormatted) freigebbar ($($inv.Categories.Count) Kategorien)"
        $lstDiskCategories.Items.Clear()

        foreach ($cat in $inv.Categories) {
            $b = New-Object System.Windows.Controls.Border
            $b.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#27272a")
            $b.CornerRadius = [System.Windows.CornerRadius]::new(6)
            $b.Padding = [System.Windows.Thickness]::new(10, 8, 10, 8)
            $b.Margin = [System.Windows.Thickness]::new(0, 0, 0, 4)
            $b.BorderThickness = [System.Windows.Thickness]::new(1)
            $b.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#3f3f46")

            $g = New-Object System.Windows.Controls.Grid
            $col1 = New-Object System.Windows.Controls.ColumnDefinition
            $col1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
            $col2 = New-Object System.Windows.Controls.ColumnDefinition
            $col2.Width = [System.Windows.GridLength]::Auto
            $g.ColumnDefinitions.Add($col1)
            $g.ColumnDefinitions.Add($col2)

            $stk = New-Object System.Windows.Controls.StackPanel
            $cn = New-Object System.Windows.Controls.TextBlock
            $cn.Text = "$($cat.Name)"
            $cn.FontSize = 13
            $cn.FontWeight = [System.Windows.FontWeights]::SemiBold
            $cn.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#f4f4f5")
            $stk.Children.Add($cn) | Out-Null

            $cd = New-Object System.Windows.Controls.TextBlock
            $cd.Text = "$($cat.Description) ($($cat.FileCount) Dateien)"
            $cd.FontSize = 11
            $cd.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#a1a1aa")
            $stk.Children.Add($cd) | Out-Null
            [System.Windows.Controls.Grid]::SetColumn($stk, 0)
            $g.Children.Add($stk) | Out-Null

            $szBadge = New-Object System.Windows.Controls.Border
            $szBadge.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#0369a1")
            $szBadge.CornerRadius = [System.Windows.CornerRadius]::new(4)
            $szBadge.Padding = [System.Windows.Thickness]::new(8, 4, 8, 4)
            $szBadge.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
            $st = New-Object System.Windows.Controls.TextBlock
            $st.Text = "$($cat.SizeText)"
            $st.FontSize = 11
            $st.FontWeight = [System.Windows.FontWeights]::Bold
            $st.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#ffffff")
            $szBadge.Child = $st
            [System.Windows.Controls.Grid]::SetColumn($szBadge, 1)
            $g.Children.Add($szBadge) | Out-Null

            $b.Child = $g
            $lstDiskCategories.Items.Add($b) | Out-Null
        }
        Log-Tidy "[SPEICHER] Analyse fertig: $($inv.TotalFormatted) freigebbar."
    }

    $btnAnalyzeDisk.Add_Click({
        & $analyzeDiskAction
    })

    $btnExecuteClean.Add_Click({
        $level = Get-SelectedSafetyLevel
        if ($level -eq 3) {
            $warn = [System.Windows.MessageBox]::Show("Stufe 3 fuehrt eine Tiefenbereinigung inklusive DISM Component-Store Bereinigung durch. Moechtest du fortfahren?", "Tiefenbereinigung bestaetigen", [System.Windows.MessageBoxButton]::YesNo, [System.Windows.MessageBoxImage]::Warning)
            if ($warn -ne [System.Windows.MessageBoxResult]::Yes) {
                Log-Tidy "[SPEICHER] Bereinigung Stufe 3 abgebrochen."
                return
            }
        }

        Log-Tidy "=== Starte Dateisystem-Bereinigung (Sicherheitsstufe $level) ==="
        try {
            $cleanResult = Invoke-DiskCleanupTier -SafetyLevel $level
            Log-Tidy "[ERFOLG] Bereinigung abgeschlossen! $($cleanResult.DeletedFiles) Dateien geloescht ($($cleanResult.FreedFormatted) Speicherplatz freigegeben)."
            if ($cleanResult.SkippedLocked -gt 0) {
                Log-Tidy "[INFO] $($cleanResult.SkippedLocked) aktive/gesperrte Dateien wurden sicher uebersprungen."
            }
            if ($cleanResult.DismCleanupRun) {
                Log-Tidy "[ERFOLG] DISM Component Store Bereinigung erfolgreich abgeschlossen."
            }
            & $analyzeDiskAction
        } catch {
            Log-Tidy "[FEHLER] Fehler bei der Bereinigung: $_"
        }
    })

    $btnCloseTidyUp.Add_Click({
        $tidyWin.Close()
    })

    # Initial load of apps list and level 1 scan
    & $refreshAppsList
    & $analyzeDiskAction

    $tidyWin.ShowDialog() | Out-Null
}

# Attach Main Window Button Events
$btnOpenScan.Add_Click({
    Show-ScanDialog
})

$btnOpenTidyUp.Add_Click({
    Show-TidyUpDialog
})

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
        Log-Ui "Keine Snapshots zum Rueckgaengig machen vorhanden."
        return
    }
    $latest = $snapshots[0]
    Log-Ui "Rueckgaengig machen von letztem Snapshot: $($latest.TweakId)..."
    try {
        Restore-RegistrySnapshot -SnapshotFilePath $latest.File
        Log-Ui "[ERFOLG] Erfolgreich rueckgaengig gemacht: $($latest.TweakId) -> Originalzustand wiederhergestellt."
        Refresh-SnapshotsList
    } catch {
        Log-Ui "[FEHLER] Fehler beim Rollback: $_"
    }
})

$btnRollbackSelected.Add_Click({
    $idx = $cmbSnapshots.SelectedIndex
    $snapshots = Get-RegistrySnapshots
    if ($idx -lt 0 -or $idx -ge $snapshots.Count) {
        Log-Ui "Ungueltige Auswahl fuer Rollback."
        return
    }
    $chosen = $snapshots[$idx]
    Log-Ui "Rueckgaengig machen von Snapshot: $($chosen.TweakId)..."
    try {
        Restore-RegistrySnapshot -SnapshotFilePath $chosen.File
        Log-Ui "[ERFOLG] Erfolgreich rueckgaengig gemacht: $($chosen.TweakId) -> Originalzustand wiederhergestellt."
        Refresh-SnapshotsList
    } catch {
        Log-Ui "[FEHLER] Fehler beim Rollback: $_"
    }
})

# Initialize UI Data on Load
$window.Add_Loaded({
    Refresh-HardwareInfo
    Refresh-SnapshotsList
    Log-Ui "Surface Pro 6 Tuner Suite v1.1.0 bereit."
    Log-Ui "Klicke auf [System scannen] fuer den interaktiven Health-Audit oder [Tidy Up] fuer App- & Speicher-Bereinigung."
})

# Launch GUI
$app = New-Object System.Windows.Application
$app.Run($window) | Out-Null
