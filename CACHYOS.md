# CachyOS Optimierungen für AMD ROCm

CachyOS bietet mehrere Vorteile für AMD GPU / ROCm Workloads (besonders Ryzen APUs).

## Optimized Repositories

CachyOS stellt optimierte Repositories bereit:

| Repository       | Ziel-CPUs          | Optimierung                  |
|------------------|--------------------|------------------------------|
| `znver4`         | AMD Zen 4 & Zen 5  | `-march=znver4` (volle AVX-512 + Zen4-spezifische Instruktionen) |
| `x86-64-v4`      | AVX-512 CPUs       | x86-64-v4 Feature Level      |
| `x86-64-v3`      | 2012+              | AVX/AVX2                     |

**Für Zen4/Zen5 (z. B. 8845HS, 8835H, AI 370/470):**

Das `znver4`-Repository wird bei Neuinstallation automatisch ausgewählt.

### Prüfen und wechseln

```bash
# CPU-Architektur prüfen
gcc -march=native -Q --help=target 2>&1 | grep -Po "^\s+-march=\s+\K(\w+)"
# Sollte znver4 oder znver5 zeigen

# Oder
/lib/ld-linux-x86-64.so.2 --help | grep supported
```

In `/etc/pacman.conf` die CachyOS-Sections auf `*-znver4` umstellen und Pakete neu installieren.

## Kernel

- **linux-cachyos**: Clang ThinLTO + AutoFDO (Profile-Guided Optimization)
- **BORE Scheduler** (optional, in manchen Varianten)
- Timer Frequency: 1000 Hz (Standard)
- **amd_pstate** mit Preferred Core Support
- PREEMPT_DYNAMIC

Empfehlung: Standard `linux-cachyos` oder BORE-Variante verwenden.

## AMD P-State

Siehe [AMD_PSTATE.md](AMD_PSTATE.md) für Details.

Kurz:

- `amd_pstate=active` (Autonomous / EPP Mode) ist empfohlen
- `power-profiles-daemon` (CachyOS-Version unterstützt AMD CPB)

## ROCm auf CachyOS

```bash
sudo pacman -Syu
sudo pacman -S rocm-core rocm-hip-runtime rocminfo rocm-smi-lib
# oder mehr Packages via AUR: paru -S rocm-hip-sdk
```

Danach User zu Gruppen hinzufügen und neu anmelden:

```bash
sudo usermod -a -G render,video $USER
```

## Praktische Tipps

1. `znver4`-Repositories verwenden (falls Zen4/5)
2. `amd_pstate=active` + passendes Power Profile
3. `gpu_recovery=1` für amdgpu (siehe [DRIVER_MODULES.md](DRIVER_MODULES.md))
4. Aktuellen Kernel behalten

## Weiterführende Links

- [CachyOS Kernel Wiki](https://wiki.cachyos.org/features/kernel/)
- [Optimized Repositories](https://wiki.cachyos.org/features/optimized_repos/)
- [General System Tweaks](https://wiki.cachyos.org/configuration/general_system_tweaks/)
