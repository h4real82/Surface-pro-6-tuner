# Surface Pro 6 Tuner 🚀

> Ein maßgeschneiderter Performance-, Thermal- und Debloating-Tuner für das **Microsoft Surface Pro 6 (Model 1796)**.

---

## 🎯 Über das Projekt

Das Microsoft Surface Pro 6 leidet unter spezifischen Hardware- und Firmware-Einschränkungen (wie aggressives Thermal Throttling via Intel DPTF / BD-PROCHOT bei 400 MHz). Gleichzeitig führen Standard-Windows-Debloater auf Surface-Geräten häufig zu Defekten bei Touchscreen, Pen-Latenz oder Modern Standby (Connected Standby).

Dieses Projekt kombiniert die stärksten Ansätze führender Windows-Tuning-Tools mit einer strikten Sicherheitsarchitektur:

1. **Safety First**: Vorab-Validierung gegen eine Hardware-AllowList und automatische 1-Klick-Registry-Snapshots (inspiriert von *Win11Debloat*).
2. **Asynchrone Ausführung**: Modulares Runspace-Pooling ohne Blockieren der UI (inspiriert von *Chris Titus Tech WinUtil*).
3. **Hardware-Unthrottling**: Firmware-Level-Entsperrung des 400-MHz-Bugs (inspiriert von *DisablePROCHOT*).
4. **Präzises OS-Tuning**: Idempotente Service- und Capability-Bereinigung (inspiriert von *Sophia Script*).

---

## 📁 Projektstruktur

```text
Surface-pro-6-tuner/
├── SurfacePro6Tuner.exe             # 🖥️ Eigenständige native Windows GUI App (Zero-Console)
├── SurfaceTuner.ps1                 # Haupt-CLI & Headless Automation Engine
├── Start-Tuner.bat                  # Alternativer 1-Klick CMD-Launcher
├── src/
│   ├── gui/                         # Moderne Fluent Dark WPF-Oberfläche
│   │   ├── MainWindow.xaml          # XAML UI-Design (Karten, Fallback-Menü, Live-Log)
│   │   ├── App.ps1                  # WPF-Controller & Event-Binding
│   │   ├── Launcher.cs              # Native C# GUI-Wrapper
│   │   └── app.manifest             # UAC-Manifest (fordert requireAdministrator an)
│   ├── engine/                      # Asynchrone Job-Engine & Profil-Runner
│   │   └── Job-Runner.ps1
│   ├── hardware/                    # Hardware-Erkennung & PROCHOT-Thermal-Monitoring
│   │   └── Thermal-Manager.ps1
│   ├── profiles/                    # Deklarative Surface Pro 6 Tuning-Profile
│   │   └── Tuning-Definitions.json
│   └── safety/                      # Sicherheits- & Validierungsschicht
│       ├── Surface-AllowList.json   # Hardware-Schutzmatrix (Touch, DPTF, Sensoren)
│       ├── Registry-Validator.ps1   # Validiert geplante Tweaks vor Ausfuehrung
│       ├── Backup-Manager.ps1       # Erstellt Pre-Tweak Snapshots & Rollbacks
│       └── Test-SafetyModule.ps1   # Automatisierte Unit-Tests fuer Safety Gates
├── tests/                           # Test Suiten
│   ├── Test-TunerE2E.ps1            # End-to-End Integrations-Tests
│   └── Test-GuiSyntax.ps1           # GUI- & XAML-Validierung
├── backups/                         # Lokale Rollback-Snapshots (in .gitignore)
├── ref/                             # Geklonte Referenzprojekte (in .gitignore)
├── .agents/                         # Antigravity Rules & Workflows
├── .antigravityignore               # Ausschlussmuster fuer Token-Schutz
├── .gitignore                       # Git-Ausschlüsse
└── README.md                        # Projektdokumentation
```

---

## 🚀 Nutzung

### 1. Als Windows Desktop App (Empfohlen)
Starte einfach direkt per Doppelklick die Anwendung:
👉 **[`SurfacePro6Tuner.exe`](file:///c:/Users/h4rea/Documents/Projekte/Surface-pro-6-tuner/SurfacePro6Tuner.exe)**

* **Kein schwarzes Konsolenfenster**: Startet sofort als moderne, native Windows-Anwendung im Fluent Dark Design.
* **Automatische Rechteerhöhung**: Fordert über das Windows-UAC-Manifest automatisch Administratorrechte an, damit Änderungen ohne Zugriffsfehler ins System geschrieben werden können.
* **🔍 System Health & Optimierungs-Scanner**:
  - Analysiert das System live gegen alle empfohlenen Tweaks, Akkuzustand und CPU-Drosselung.
  - Zeigt einen interaktiven Optimierungs-Score (0–100%) mit Statusplaketten an (`[OPTIMIERT]` vs. `[OFFEN]`).
  - Erlaubt das gezielte Anwenden einzelner Empfehlungen oder aller Tweaks mit 1 Klick.
* **🧹 Tidy Up & Deep Cleaner**:
  - **Windows Apps & Bloatware deinstallieren**: Entfernt vorinstallierte Apps (wie Solitär, Xbox Game Bar, Clipchamp, Microsoft News etc.) restlos für alle Benutzer sowie aus dem Online-Provisioning, sodass sie auch bei künftigen Windows-Updates nicht zurückkehren.
  - **Speicher- & Cache-Bereinigung nach 3 Sicherheitsstufen**:
    - **Stufe 1 (Sicher / Basis - 0% Risiko)**: Benutzer-Temp, System-Temp, Fehlerberichte, Miniaturansichten und Browser-Caches.
    - **Stufe 2 (Erweitert / Standard)**: Inklusive Windows Update Download-Cache, Delivery-Optimization, DirectX Shader Cache & Prefetch.
    - **Stufe 3 (Tiefenreinigung / Aggressiv)**: Inklusive DISM Component-Store Bereinigung und alter Windows-Installationen (`Windows.old`).
  - Integrierte Speicherplatzanalyse mit exakter MB/GB-Vorschau.
* **Moderne Aktions-Karten**:
  - `[Performance anwenden]`: Deaktiviert Telemetrie, GameDVR, Cortana und Web-Suche.
  - `[Akku anwenden]`: Schaltet Connected Standby Wake-Timer ab und drosselt Hintergrund-Apps.
  - `[Thermal unthrotteln]`: Wirkt dem 400-MHz-BD-PROCHOT-Lock des Surface Pro 6 entgegen.
  - `[Alles optimieren]`: Wendet alle empfohlenen Tweaks in einem Schritt an.
* **Eingebaute Fallback-Funktion (Rückgängig machen)**:
  - Jeder angewandte Tweak erzeugt automatisch ein Snapshot in `backups/`.
  - Über das Dropdown-Menü oder den Button `[Letzte Aktion rückgängig machen]` kann jede Aktion mit 1 Klick auf den Originalzustand zurückgerollt werden.
* **Live-Aktivitätslog**: Detaillierte Echtzeit-Rückmeldung über alle Vorgänge direkt im Fenster.

### 2. Headless & CLI-Automation (Silent Mode)
```powershell
# Vollstaendige Optimierung ohne Rueckfragen (Headless JSON Output)
powershell -ExecutionPolicy Bypass -File SurfaceTuner.ps1 -Profile All -AutoAccept -Headless

# Hardware & Throttling Status abfragen
powershell -ExecutionPolicy Bypass -File SurfaceTuner.ps1 -Status

# Simulation / Safety-Check (Dry-Run)
powershell -ExecutionPolicy Bypass -File SurfaceTuner.ps1 -Profile All -DryRun

# Rollback auf das vorherige Snapshot
powershell -ExecutionPolicy Bypass -File SurfaceTuner.ps1 -Rollback
```

---

## 🧪 Tests ausführen

```powershell
# Safety Module Unit-Tests
powershell -ExecutionPolicy Bypass -File src/safety/Test-SafetyModule.ps1

# End-to-End Integrations-Tests
powershell -ExecutionPolicy Bypass -File tests/Test-TunerE2E.ps1
```

---

## 📜 Lizenz & Referenzen

Basiert auf Architekturen und Konzepten von:
- [Win11Debloat](https://github.com/Raphire/Win11Debloat)
- [winutil](https://github.com/ChrisTitusTech/winutil)
- [Sophia-Script-for-Windows](https://github.com/farag2/Sophia-Script-for-Windows)
- [DisablePROCHOT](https://github.com/arter97/DisablePROCHOT)

