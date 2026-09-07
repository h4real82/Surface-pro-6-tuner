<#
.SYNOPSIS
    Surface Pro 6 Tuner - Tidy Up Engine (App Remover & Disk/Cache Cleaner)
.DESCRIPTION
    Provides clean uninstallation of pre-installed Windows apps (e.g. Solitaire, Xbox, Bloatware)
    without residual files across all user profiles and online provisioning.
    Implements a 3-tier safety concept for clearing temporary, cache, and system storage.
#>

$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root "safety\Backup-Manager.ps1")

# Protected critical apps that must never be removed
$script:ProtectedAppxPatterns = @(
    "Microsoft.WindowsStore",
    "Microsoft.DesktopAppInstaller",
    "Microsoft.SecHealthUI",
    "Microsoft.Windows.Search",
    "Microsoft.Windows.ShellExperienceHost",
    "Microsoft.Windows.StartMenuExperienceHost",
    "Microsoft.WindowsTerminal",
    "Microsoft.WindowsCalculator",
    "Microsoft.WindowsNotepad"
)

function Get-DebloatAppCatalog {
    return @(
        @{
            Id          = "Microsoft.MicrosoftSolitaireCollection"
            DisplayName = "Microsoft Solitaire Collection"
            Category    = "Spiele & Bloatware"
            Description = "Vorinstallierte Kartenspiel-App mit Werbung und Hintergrund-Telemetrie."
            Safe        = $true
        },
        @{
            Id          = "Microsoft.XboxApp"
            DisplayName = "Xbox Konsole-Begleiter"
            Category    = "Gaming"
            Description = "Aeltere Xbox Begleit-App, wird auf mobilen Surface-Geraeten selten benoetigt."
            Safe        = $true
        },
        @{
            Id          = "Microsoft.XboxGamingOverlay"
            DisplayName = "Xbox Game Bar Overlay"
            Category    = "Gaming"
            Description = "Game-Bar Overlay. Verbraucht im Hintergrund RAM und GPU-Ressourcen."
            Safe        = $true
        },
        @{
            Id          = "Microsoft.XboxIdentityProvider"
            DisplayName = "Xbox Identitaets-Anbieter"
            Category    = "Gaming"
            Description = "Xbox-Anmeldedienst fuer Microsoft Games."
            Safe        = $true
        },
        @{
            Id          = "Microsoft.XboxSpeechToTextOverlay"
            DisplayName = "Xbox Sprach-zu-Text Overlay"
            Category    = "Gaming"
            Description = "Sprach-Overlay fuer Xbox-Party-Chat."
            Safe        = $true
        },
        @{
            Id          = "Clipchamp.Clipchamp"
            DisplayName = "Clipchamp Video-Editor"
            Category    = "Medien & Promotion"
            Description = "Vorinstallierter Cloud-basierter Video-Editor."
            Safe        = $true
        },
        @{
            Id          = "Microsoft.WindowsFeedbackHub"
            DisplayName = "Feedback-Hub"
            Category    = "System-Tools"
            Description = "Sammelt Feedback und sendet Diagnosedaten an Microsoft."
            Safe        = $true
        },
        @{
            Id          = "Microsoft.GetHelp"
            DisplayName = "Hilfe anfordern (Tips/GetHelp)"
            Category    = "System-Tools"
            Description = "Support- und Tipp-App von Windows."
            Safe        = $true
        },
        @{
            Id          = "Microsoft.Getstarted"
            DisplayName = "Erste Schritte (Tipps)"
            Category    = "System-Tools"
            Description = "Tipps-App fuer Windows-Neulinge."
            Safe        = $true
        },
        @{
            Id          = "Microsoft.BingNews"
            DisplayName = "Microsoft News"
            Category    = "Nachrichten & Wetter"
            Description = "Nachrichten-App mit staendigen Hintergrund-Feeds."
            Safe        = $true
        },
        @{
            Id          = "Microsoft.BingWeather"
            DisplayName = "Microsoft Wetter"
            Category    = "Nachrichten & Wetter"
            Description = "Wetter-App mit Hintergrundaktualisierung."
            Safe        = $true
        },
        @{
            Id          = "Microsoft.Microsoft3DViewer"
            DisplayName = "3D Viewer"
            Category    = "3D & Mixed Reality"
            Description = "3D-Modell-Betrachter (wird selten verwendet)."
            Safe        = $true
        },
        @{
            Id          = "Microsoft.MixedReality.Portal"
            DisplayName = "Mixed Reality-Portal"
            Category    = "3D & Mixed Reality"
            Description = "VR/MR Schnittstelle, auf dem Surface Pro 6 meist ungenutzt."
            Safe        = $true
        },
        @{
            Id          = "SpotifyAB.SpotifyMusic"
            DisplayName = "Spotify (Vorinstalliert)"
            Category    = "Medien & Promotion"
            Description = "Vorinstallierte Spotify-Promotion-App."
            Safe        = $true
        },
        @{
            Id          = "Disney.37853FC22B2CE"
            DisplayName = "Disney+"
            Category    = "Medien & Promotion"
            Description = "Vorinstallierte Streaming-App-Verknuepfung."
            Safe        = $true
        },
        @{
            Id          = "ByteDancePte.Ltd.TikTok"
            DisplayName = "TikTok"
            Category    = "Medien & Promotion"
            Description = "Vorinstallierte TikTok-Promotion-App."
            Safe        = $true
        },
        @{
            Id          = "Microsoft.SkypeApp"
            DisplayName = "Skype"
            Category    = "Kommunikation"
            Description = "Vorinstallierte UWP Skype-Version."
            Safe        = $true
        },
        @{
            Id          = "Microsoft.YourPhone"
            DisplayName = "Smartphone-Link"
            Category    = "System-Tools"
            Description = "Synchronisation mit Android/iOS Smartphone."
            Safe        = $false
        }
    )
}

function Get-InstalledDebloatApps {
    [CmdletBinding()]
    param()

    $catalog = Get-DebloatAppCatalog
    $installedUserPackages = @()
    try {
        $installedUserPackages = @(Get-AppxPackage -AllUsers -ErrorAction Stop)
    } catch {
        $installedUserPackages = @(Get-AppxPackage -ErrorAction SilentlyContinue)
    }

    $provisionedPackages = @()
    try {
        $provisionedPackages = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop)
    } catch {
        # Provisioned packages query requires elevation, skip gracefully if non-admin
    }

    $results = @()
    foreach ($entry in $catalog) {
        $isInstalled = $false
        $packageFullName = ""

        $matchingUser = $installedUserPackages | Where-Object { $_.Name -like "*$($entry.Id)*" } | Select-Object -First 1
        if ($matchingUser) {
            $isInstalled = $true
            $packageFullName = $matchingUser.PackageFullName
        }

        $matchingProv = $provisionedPackages | Where-Object { $_.PackageName -like "*$($entry.Id)*" } | Select-Object -First 1
        if ($matchingProv) {
            $isInstalled = $true
            if (-not $packageFullName) {
                $packageFullName = $matchingProv.PackageName
            }
        }

        $results += [PSCustomObject]@{
            Id              = $entry.Id
            DisplayName     = $entry.DisplayName
            Category        = $entry.Category
            Description     = $entry.Description
            Safe            = $entry.Safe
            IsInstalled     = $isInstalled
            PackageFullName = $packageFullName
            StatusText      = $(if ($isInstalled) { "Installiert" } else { "Nicht vorhanden" })
        }
    }

    return $results
}

function Uninstall-DebloatApp {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AppId
    )

    # Check Whitelist
    foreach ($prot in $script:ProtectedAppxPatterns) {
        if ($AppId -like "*$prot*") {
            throw "Sicherheits-Schutz: App [$AppId] gehoert zu geschuetzten Windows-Kernkomponenten und darf nicht entfernt werden."
        }
    }

    $errors = @()
    $removedCount = 0

    # 1. Remove from all active user profiles
    $userPackages = @(Get-AppxPackage -Name "*$AppId*" -AllUsers -ErrorAction SilentlyContinue)
    foreach ($pkg in $userPackages) {
        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop
            $removedCount++
        } catch {
            $errors += "User Package Fehler ($($pkg.PackageFullName)): $_"
        }
    }

    # 2. Remove from online provisioned image so it never re-installs on updates/new users
    $provPackages = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.PackageName -like "*$AppId*" -or $_.DisplayName -like "*$AppId*" })
    foreach ($prov in $provPackages) {
        try {
            Remove-ProvisionedAppxPackage -Online -PackageName $prov.PackageName -AllUsers -ErrorAction Stop | Out-Null
            $removedCount++
        } catch {
            $errors += "Provisioned Package Fehler ($($prov.PackageName)): $_"
        }
    }

    return [PSCustomObject]@{
        AppId        = $AppId
        RemovedCount = $removedCount
        Success      = ($errors.Count -eq 0)
        Errors       = $errors
    }
}

# ==============================================================================
# DISK & CACHE CLEANUP ENGINE (3 SAFETY CONCEPT LEVELS)
# ==============================================================================

function Get-CleanupTargetPaths {
    param([int]$SafetyLevel)

    $targets = @()

    # --- LEVEL 1: SICHER / BASIS ---
    # Gefahrlos, reine Caches und temporaere Arbeitsdaten
    $userTemp = [System.IO.Path]::GetTempPath()
    if (Test-Path $userTemp) {
        $targets += [PSCustomObject]@{
            Name        = "Benutzer Temp-Dateien"
            Path        = $userTemp
            Filter      = "*.*"
            Level       = 1
            Description = "Temporaere Arbeitsdateien des aktuellen Benutzers"
        }
    }

    $sysTemp = "$env:SystemRoot\Temp"
    if (Test-Path $sysTemp) {
        $targets += [PSCustomObject]@{
            Name        = "Windows System-Temp"
            Path        = $sysTemp
            Filter      = "*.*"
            Level       = 1
            Description = "Temporaere Arbeitsdateien von Windows-Systemdiensten"
        }
    }

    $werPath = "$env:ProgramData\Microsoft\Windows\WER"
    if (Test-Path $werPath) {
        $targets += [PSCustomObject]@{
            Name        = "Fehlerberichte (WER Crash Reports)"
            Path        = $werPath
            Filter      = "*.*"
            Level       = 1
            Description = "Alte Absturz- und Problemberichte der Windows-Fehlerberichterstattung"
        }
    }

    $thumbCache = "$env:LocalAppData\Microsoft\Windows\Explorer"
    if (Test-Path $thumbCache) {
        $targets += [PSCustomObject]@{
            Name        = "Miniaturansichten (Thumbnails)"
            Path        = $thumbCache
            Filter      = "thumbcache_*.db"
            Level       = 1
            Description = "Gecachte Vorschau-Bilder des Windows Explorers"
        }
    }

    # Web Browser Caches
    $edgeCache = "$env:LocalAppData\Microsoft\Edge\User Data\Default\Cache"
    if (Test-Path $edgeCache) {
        $targets += [PSCustomObject]@{
            Name        = "Microsoft Edge Web-Cache"
            Path        = $edgeCache
            Filter      = "*.*"
            Level       = 1
            Description = "Zwischengespeicherte Web-Dateien von Microsoft Edge (keine Passwoerter/Chronik)"
        }
    }

    $chromeCache = "$env:LocalAppData\Google\Chrome\User Data\Default\Cache"
    if (Test-Path $chromeCache) {
        $targets += [PSCustomObject]@{
            Name        = "Google Chrome Web-Cache"
            Path        = $chromeCache
            Filter      = "*.*"
            Level       = 1
            Description = "Zwischengespeicherte Web-Dateien von Google Chrome"
        }
    }

    # --- LEVEL 2: ERWEITERT / STANDARD ---
    # Windows Update Download & Delivery Optimization & Shader Cache
    if ($SafetyLevel -ge 2) {
        $wuDownload = "$env:SystemRoot\SoftwareDistribution\Download"
        if (Test-Path $wuDownload) {
            $targets += [PSCustomObject]@{
                Name        = "Windows Update Download-Cache"
                Path        = $wuDownload
                Filter      = "*.*"
                Level       = 2
                Description = "Bereits installierte Windows Update Installationspakete"
            }
        }

        $wuDeliv = "$env:SystemRoot\SoftwareDistribution\DeliveryOptimization"
        if (Test-Path $wuDeliv) {
            $targets += [PSCustomObject]@{
                Name        = "Übermittlungsoptimierungs-Cache"
                Path        = $wuDeliv
                Filter      = "*.*"
                Level       = 2
                Description = "Zwischengespeicherte Update-Dateien fuer die Peer-to-Peer-Verteilung"
            }
        }

        $dxCache = "$env:LocalAppData\D3DSCache"
        if (Test-Path $dxCache) {
            $targets += [PSCustomObject]@{
                Name        = "DirectX Shader-Cache"
                Path        = $dxCache
                Filter      = "*.*"
                Level       = 2
                Description = "Kompilierte GPU-Shader-Caches (entlastet Intel UHD 620 Speicher)"
            }
        }

        $prefetch = "$env:SystemRoot\Prefetch"
        if (Test-Path $prefetch) {
            $targets += [PSCustomObject]@{
                Name        = "Windows Prefetch-Dateien"
                Path        = $prefetch
                Filter      = "*.pf"
                Level       = 2
                Description = "Veraltete Start-Indizes fuer Programme"
            }
        }
    }

    # --- LEVEL 3: TIEFENREINIGUNG / AGGRESSIV ---
    if ($SafetyLevel -ge 3) {
        $winOld = "C:\Windows.old"
        if (Test-Path $winOld) {
            $targets += [PSCustomObject]@{
                Name        = "Vorherige Windows-Installationen (Windows.old)"
                Path        = $winOld
                Filter      = "*.*"
                Level       = 3
                Description = "Alte Sicherung frueherer Windows-Versionen nach Funktions-Updates"
            }
        }
    }

    return $targets
}

function Get-DiskCleanupInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 3)]
        [int]$SafetyLevel = 1
    )

    $targets = Get-CleanupTargetPaths -SafetyLevel $SafetyLevel
    $inventory = @()
    $totalBytes = 0

    foreach ($target in $targets) {
        $bytes = 0
        $fileCount = 0

        try {
            if (Test-Path $target.Path) {
                $files = Get-ChildItem -Path $target.Path -Filter $target.Filter -Recurse -File -Force -ErrorAction SilentlyContinue
                if ($files) {
                    $measure = $files | Measure-Object -Property Length -Sum
                    $bytes = [int64]$measure.Sum
                    $fileCount = [int]$measure.Count
                }
            }
        } catch {
            # Inaccessible file handling
        }

        $totalBytes += $bytes
        $mb = [Math]::Round(($bytes / 1MB), 2)

        $inventory += [PSCustomObject]@{
            Name        = $target.Name
            Path        = $target.Path
            Level       = $target.Level
            Description = $target.Description
            FileCount   = $fileCount
            Bytes       = $bytes
            SizeMB      = $mb
            SizeText    = $(if ($mb -ge 1024) { "$([Math]::Round($mb / 1024, 2)) GB" } else { "$mb MB" })
        }
    }

    $totalMB = [Math]::Round(($totalBytes / 1MB), 2)
    $totalFormatted = if ($totalMB -ge 1024) { "$([Math]::Round($totalMB / 1024, 2)) GB" } else { "$totalMB MB" }

    return [PSCustomObject]@{
        SafetyLevel     = $SafetyLevel
        TotalBytes      = $totalBytes
        TotalMB         = $totalMB
        TotalFormatted  = $totalFormatted
        Categories      = $inventory
    }
}

function Invoke-DiskCleanupTier {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 3)]
        [int]$SafetyLevel = 1,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    $targets = Get-CleanupTargetPaths -SafetyLevel $SafetyLevel
    $deletedFiles = 0
    $freedBytes = 0
    $skippedLocked = 0

    foreach ($target in $targets) {
        if (-not (Test-Path $target.Path)) { continue }

        try {
            $files = Get-ChildItem -Path $target.Path -Filter $target.Filter -Recurse -File -Force -ErrorAction SilentlyContinue
            foreach ($f in $files) {
                $len = $f.Length
                if ($DryRun) {
                    $freedBytes += $len
                    $deletedFiles++
                } else {
                    try {
                        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                        $freedBytes += $len
                        $deletedFiles++
                    } catch {
                        # File is locked or currently in use by a process
                        $skippedLocked++
                    }
                }
            }

            # Remove empty subdirectories if not dry run
            if (-not $DryRun) {
                Get-ChildItem -Path $target.Path -Recurse -Directory -Force -ErrorAction SilentlyContinue |
                    Sort-Object -Property FullName -Descending |
                    Where-Object { (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0 } |
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            }
        } catch {
            # Continue with next target
        }
    }

    # If SafetyLevel is 3, also invoke DISM Component Cleanup asynchronously if not DryRun
    $dismTriggered = $false
    if ($SafetyLevel -ge 3 -and (-not $DryRun)) {
        try {
            Start-Process -FilePath "Dism.exe" -ArgumentList "/Online /Cleanup-Image /StartComponentCleanup /NoRestart" -WindowStyle Hidden -Wait
            $dismTriggered = $true
        } catch {
            # Dism failure logged gracefully
        }
    }

    $freedMB = [Math]::Round(($freedBytes / 1MB), 2)
    $freedFormatted = if ($freedMB -ge 1024) { "$([Math]::Round($freedMB / 1024, 2)) GB" } else { "$freedMB MB" }

    return [PSCustomObject]@{
        SafetyLevel     = $SafetyLevel
        DryRun          = $DryRun
        DeletedFiles    = $deletedFiles
        SkippedLocked   = $skippedLocked
        FreedBytes      = $freedBytes
        FreedFormatted  = $freedFormatted
        DismCleanupRun  = $dismTriggered
    }
}
