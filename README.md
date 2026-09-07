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
├── src/
│   └── safety/                      # Sicherheits- & Validierungsschicht
│       ├── Surface-AllowList.json   # Hardware-Schutzmatrix (Touch, DPTF, Sensoren)
│       ├── Registry-Validator.ps1   # Validiert geplante Tweaks vor Ausführung
│       ├── Backup-Manager.ps1       # Erstellt Pre-Tweak Snapshots & Rollbacks
│       └── Test-SafetyModule.ps1   # Automatisierte Unit-Tests für Safety Gates
├── backups/                         # Lokale Rollback-Snapshots (in .gitignore)
├── ref/                             # Geklonte Referenzprojekte (in .gitignore)
├── .agents/                         # Antigravity Rules & Workflows
├── .antigravityignore               # Ausschlussmuster für Token-Schutz
├── .gitignore                       # Git-Ausschlüsse
└── README.md                        # Projektdokumentation
```

---

## 🛡️ Sicherheitsarchitektur (`src/safety`)

Vor jedem Eingriff in das System greift die zweistufige Schutzschicht:

1. **Hardware Protection Gate**:
   - Schützt kritische Treiber (`Services\Surface*`, `Services\Sensor*`, `TouchScreen*`).
   - Verhindert CPU-Throttling-Schäden durch Schutz von Intel DPTF (`Services\dptf*`).
   - Schützt Connected Standby Einstellungen (`CsEnabled`, `PlatformAoAcOverride`).
2. **Snapshot & Rollback**:
   - Speichert den Originalwert und -typ (`DWord`, `String`, etc.) in `backups/`.
   - Ermöglicht jederzeit die vollständige Wiederherstellung.

### Tests ausführen

```powershell
powershell -ExecutionPolicy Bypass -File src/safety/Test-SafetyModule.ps1
```

---

## 📜 Lizenz & Referenzen

Basiert auf Architekturen und Konzepten von:
- [Win11Debloat](https://github.com/Raphire/Win11Debloat)
- [winutil](https://github.com/ChrisTitusTech/winutil)
- [Sophia-Script-for-Windows](https://github.com/farag2/Sophia-Script-for-Windows)
- [DisablePROCHOT](https://github.com/arter97/DisablePROCHOT)
