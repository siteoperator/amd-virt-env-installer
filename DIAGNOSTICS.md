# ROCm Systemdiagnose-Tools

Übersicht der wichtigsten Tools zur Prüfung, ob ROCm und die AMD-GPU korrekt funktionieren.

## 1. rocminfo – HSA-Agenten & Architektur

**Wichtigstes Diagnose-Tool.** Zeigt, ob die GPU von der ROCm-Runtime erkannt wird.

```bash
rocminfo
# oder kompakter:
rocminfo | grep -E 'Marketing|Name|gfx|Device Type'
```

**Was du sehen solltest:**
- Mindestens einen `Agent` mit `Device Type: GPU`
- Eine `Marketing Name` (z. B. `Radeon RX 7900 XTX` oder `gfx1103`)
- Eine `Name: gfx…`-Zeile (z. B. `gfx1100`, `gfx1103`, `gfx1030`)

**Häufige Probleme:**
- Kein GPU-Agent → Gruppen fehlen (`render`, `video`) oder Treiber nicht geladen
- Nur CPU-Agent → ROCm erkennt die GPU nicht
- Falsche gfx-Version → ggf. `HSA_OVERRIDE_GFX_VERSION` setzen

```bash
# Kurzcheck auf GPU
rocminfo | grep -A 5 "Device Type:.*GPU"
```

## 2. rocm-smi – Monitoring & Status

Klassisches Monitoring-Tool (wird langfristig durch `amd-smi` abgelöst).

```bash
# Übersicht
rocm-smi

# Temperatur, Auslastung, Power
rocm-smi --showtemp --showuse --showpower

# Speicher
rocm-smi --showmemuse --showmeminfo vram

# Alle Infos
rocm-smi -a

# JSON (scriptbar)
rocm-smi --json
```

**Live-Monitoring:**
```bash
watch -n 1 rocm-smi
```

## 3. amd-smi – Neues System Management Interface

Empfohlenes modernes Tool (Nachfolger von `rocm-smi`).

```bash
# Hilfe
amd-smi --help

# GPU-Liste
amd-smi list

# Statische Infos (Modell, VRAM, …)
amd-smi static

# Live-Metriken
amd-smi metric
amd-smi monitor

# Prozesse auf der GPU
amd-smi process

# Kompatibilitätsmodus (rocm-smi-Ausgabe)
amd-smi --rocm-smi
```

## 4. Weitere nützliche Checks

### Gruppen & Rechte
```bash
groups $USER
# sollte "render" und "video" enthalten

ls -l /dev/kfd /dev/dri/render*
```

### PCI-Geräte
```bash
lspci | grep -i amd
lspci -nn | grep 1002
```

### Kernel-Module
```bash
lsmod | grep -E 'amdgpu|amdkfd'
```

### PyTorch-Sichtbarkeit (im venv)
```bash
source venv/bin/activate
python -c "import torch; print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'No GPU')"
```

### hipcc / HIP-Version
```bash
hipcc --version
# oder
/opt/rocm/bin/hipcc --version
```

## 5. Schneller Diagnose-Workflow

```bash
# 1. Wird die GPU vom Kernel gesehen?
lspci | grep -i amd

# 2. Läuft der ROCm-Treiber?
lsmod | grep amdgpu

# 3. Sieht die ROCm-Runtime die GPU?
rocminfo | grep -E 'Marketing|gfx|GPU'

# 4. Status & Temperatur
rocm-smi || amd-smi list

# 5. PyTorch (optional)
python -c "import torch; print(torch.cuda.is_available())"
```

## 6. Typische Fehlermeldungen

| Symptom | Mögliche Ursache | Lösung |
|---------|-------------------|--------|
| `rocminfo` zeigt keine GPU | Gruppen / Treiber | `usermod -a -G render,video $USER` + Re-Login |
| `HSA_STATUS_ERROR` | Falsche gfx oder fehlende Kernel | `HSA_OVERRIDE_GFX_VERSION` prüfen |
| `Permission denied` auf `/dev/kfd` | Rechte | Gruppen + udev-Regeln |
| PyTorch sieht keine GPU | ROCm nicht im PATH / falsche Wheel | `rocminfo` zuerst prüfen |
| Hohe Temperatur / Throttling | Power-Limit / Lüfter | `rocm-smi` / `amd-smi` checken |

## 7. Nützliche Links

- rocminfo: https://rocm.docs.amd.com/projects/rocminfo/
- AMD SMI: https://rocm.docs.amd.com/projects/amdsmi/
- ROCm System Tools: https://rocm.docs.amd.com/en/latest/reference/rocm-tools.html

## Siehe auch

- [PROFILING.md](PROFILING.md)
- [PERFORMANCE.md](PERFORMANCE.md)
- [KERNEL_OPTIMIZATIONS.md](KERNEL_OPTIMIZATIONS.md)
