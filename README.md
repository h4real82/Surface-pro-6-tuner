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
├── SurfaceTuner.ps1                 # Haupt-CLI & Headless Automation Engine
├── Start-Tuner.bat                  # 1-Klick Launcher mit automatischer UAC-Erhoehung
├── src/
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
├── tests/                           # End-to-End Test Suite
│   └── Test-TunerE2E.ps1
├── backups/                         # Lokale Rollback-Snapshots (in .gitignore)
├── ref/                             # Geklonte Referenzprojekte (in .gitignore)
├── .agents/                         # Antigravity Rules & Workflows
├── .antigravityignore               # Ausschlussmuster fuer Token-Schutz
├── .gitignore                       # Git-Ausschlüsse
└── README.md                        # Projektdokumentation
```

---

## 🚀 Nutzung

### 1. 1-Klick-Starter (Interaktiv mit UAC-Abfrage)
Einfach die Datei [`Start-Tuner.bat`](file:///c:/Users/h4rea/Documents/Projekte/Surface-pro-6-tuner/Start-Tuner.bat) per Doppelklick starten. Das Skript fordert automatisch Administratorrechte an und bietet ein Menü:
1. Alles optimieren (Performance + Battery + Thermal)
2. Nur Performance & Telemetrie
3. Nur Akku & Modern Standby
4. Hardware- & Thermal-Status
5. Dry-Run Simulation (Sicherheitstest)
6. Rollback / Letztes Snapshot wiederherstellen

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

