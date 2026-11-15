# AMD P-State – Autonomous Mode

Der AMD P-State Driver steuert die CPU-Frequenz auf modernen Ryzen-Prozessoren (Zen 2+).

## Betriebsmodi

| Modus                  | Kernel-Parameter     | Verhalten |
|------------------------|----------------------|-----------|
| **Active / Autonomous** | `amd_pstate=active` | Firmware entscheidet Frequenz; OS setzt nur EPP-Hinweis |
| **Guided**             | `amd_pstate=guided` | OS setzt Min/Max; Firmware wählt innerhalb des Bereichs |
| **Passive**            | `amd_pstate=passive`| OS steuert Desired Performance vollständig |

**Autonomous Mode** (`active`) ist seit Linux 6.5 der Standard auf modernen Systemen und für Zen4/Zen5 empfohlen.

### Funktionsweise (Active Mode)

- OS setzt nur einen **Energy Performance Preference (EPP)**-Hinweis
- Die CPU-Firmware (SMU) wählt autonom die Frequenz basierend auf:
  - Workload
  - Thermik
  - Power Limits
  - EPP-Hinweis

## Energy Performance Preference (EPP)

| Preference              | Typischer Wert | Einsatz |
|-------------------------|----------------|---------|
| `power`                 | 0xFF           | Maximale Effizienz |
| `balance_power`         | 0xBF           | Bias zu Stromsparen |
| `balance_performance`   | 0x80           | Guter Allround-Default |
| `performance`           | 0x00           | Maximaler Performance-Bias |
| `default`               | Platform       | BIOS-Einstellung |

## Steuerung

```bash
# Aktuellen Modus prüfen
cat /sys/devices/system/cpu/amd_pstate/status

# Modus wechseln (temporär)
echo active | sudo tee /sys/devices/system/cpu/amd_pstate/status

# Verfügbare EPP-Optionen
cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_available_preferences

# Aktuelle EPP
cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference

# EPP für alle Kerne setzen
echo balance_performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference
```

## Empfehlungen für ROCm / Compute

Auf CachyOS mit Zen4 APUs (z. B. 8845HS):

1. Modus: `amd_pstate=active` (meist schon Default)
2. EPP: `balance_performance` oder `performance` für schwere Workloads
3. Power Profile:
   ```bash
   powerprofilesctl set performance   # oder balanced
   ```
4. Core Performance Boost bleibt verfügbar und kann per-Core gesteuert werden

## Hinweise

- Active Mode bietet auf modernen Ryzen meist bessere Responsiveness und Effizienz als Passive Mode
- Preferred Core Support funktioniert am besten im Active Mode
- Für Laptops ist `balance_performance` oft ein guter Kompromiss
- Für anhaltende ROCm-Workloads: `performance` EPP + `powerprofilesctl set performance`

## Verwandte Dokumentation

- [CACHYOS.md](CACHYOS.md)
- [ZEN4.md](ZEN4.md)
- [DRIVER_MODULES.md](DRIVER_MODULES.md)
