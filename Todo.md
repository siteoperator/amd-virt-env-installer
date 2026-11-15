# Todo – Was noch fehlen könnte

Diese Liste basiert auf dem aktuellen Stand des Repos (Stand November 2026).

| Priorität | Thema | Warum nützlich | Aufwand | Status |
|-----------|-------|----------------|---------|--------|
| **Hoch** | **Post-Install Helper** (`activate_env.sh`) | Setzt automatisch `HSA_OVERRIDE_GFX_VERSION` und empfiehlt Gruppen-Check | Klein | **Umgesetzt** |
| **Hoch** | **Firmware-Check / Update** | Auf blankem Ubuntu ist `linux-firmware` oft veraltet → GPU bindet nicht | Klein | **Umgesetzt** (in prepare_os.sh) |
| **Mittel** | **Gruppen automatisch hinzufügen** (mit klarer Warnung) | Häufigster Grund für „keine GPU in rocminfo“ | Klein | **Umgesetzt** (in prepare_os.sh) |
| **Mittel** | **Separates `check.sh`** | Nur Diagnose, ohne Installation (für Troubleshooting) | Klein | Offen |
| **Mittel** | **Python-Version absichern** | Ubuntu hat manchmal nur 3.10; viele Wheels wollen 3.11/3.12 | Mittel | Offen |
| **Niedrig** | **Cleanup / Uninstall-Skript** | Venv + optionale Pakete wieder entfernen | Klein | Offen |
| **Niedrig** | **Docker-Beispiel** | Für virtuelle/isolierte Umgebungen (passt zum Repo-Namen) | Mittel | Offen |
| **Niedrig** | **Weitere Distros** (Fedora, openSUSE) | Aktuell nur Ubuntu + CachyOS/Arch | Mittel–Hoch | Offen |
| **Optional** | **modprobe-Optionen automatisch setzen** | `gpu_recovery=1` etc. (aktuell nur dokumentiert) | Klein | Offen |

## Bereits gut abgedeckt
- Basis-Pakete (`prepare_os.sh`)
- GPU-/Modul-/Gruppen-/Permission-Checks
- HSA_OVERRIDE-Hinweise für die relevanten Ryzen-Modelle
- ROCm-Installationsanleitung (manuell, bewusst)
- PyTorch-Wheels + Verifikation
- Umfangreiche Dokumentation (Driver, Compatibility, Tuning, Profiling …)

## Nächste sinnvolle Schritte
1. `check.sh` als reines Diagnose-Skript
2. Python-Version-Check / Empfehlung in `prepare_os.sh`
3. Optional: Docker-Compose-Beispiel für isolierte ROCm-Umgebungen
