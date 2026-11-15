# AMD Virtual Environment Installer

Simple install script to set up a clean Python virtual environment with **ROCm-enabled PyTorch** on AMD GPUs.

This is useful when you want an isolated environment for ML/AI workloads (ComfyUI, Ollama, custom training, etc.) without polluting the system Python.

## Prerequisites

- AMD GPU with ROCm support (Radeon RX 6000/7000/9000 series, Instinct, or many Ryzen iGPUs)
- **Ubuntu** 22.04 / 24.04 / 26.04 **or CachyOS / Arch Linux**
- ROCm installed on the host (or use the system packages)
- Python 3.10+

```bash
# Quick check
rocminfo
# or
python3 --version
```

## Quick Start (blank system)

On a fresh Ubuntu or CachyOS installation first prepare the base packages, firmware and groups:

```bash
git clone https://github.com/siteoperator/amd-virt-env-installer.git
cd amd-virt-env-installer
chmod +x prepare_os.sh install.sh activate_env.sh
./prepare_os.sh
```

Then continue with the main installer:

```bash
./install.sh
# or with optional ROCm install guidance:
# INSTALL_ROCM=1 ./install.sh
```

After installation, activate the environment (sets `HSA_OVERRIDE` automatically for common iGPUs):

```bash
source ./activate_env.sh
```

## Was das Skript bereits prüft und abdeckt

| Bereich | Abgedeckt? | Details |
|---------|------------|---------|
| Distribution | Ja | Ubuntu vs. CachyOS/Arch |
| Kernel-Module | Ja | `amdgpu` + `amdkfd` geladen? + Parameter |
| Berechtigungen | Ja | Gruppen `render` + `video`, `/dev/kfd` |
| GPU-Erkennung | Ja | `rocminfo`, `lspci`, `rocm-smi` + Hinweise für Ryzen-Modelle |
| HSA_OVERRIDE | Ja | Warnt und zeigt passende Werte |
| Python + venv | Ja | Prüft ob vorhanden, gibt Install-Hinweis |
| PyTorch ROCm | Ja | Installiert Wheels mit Fallback-Indizes |
| Verifikation | Ja | Prüft ob PyTorch die GPU sieht |

**Hinweis:** ROCm/Treiber-Installation bleibt bewusst manuell. Gruppen können jetzt interaktiv in `prepare_os.sh` gesetzt werden (Re-Login erforderlich).

## Quick Start

```bash
git clone https://github.com/siteoperator/amd-virt-env-installer.git
cd amd-virt-env-installer
chmod +x install.sh
./install.sh
```

The script will:
1. Detect your distribution (Ubuntu / CachyOS / Arch)
2. Check AMDGPU / amdkfd kernel modules and key parameters
3. Detect your AMD GPU / iGPU (via `rocminfo`, `lspci` and `rocm-smi`)
4. Optionally install system ROCm (if `INSTALL_ROCM=1`)
5. Create a virtual environment (`./venv` by default)
6. Upgrade pip
7. Install the latest stable ROCm PyTorch wheels
8. Verify that the GPU is visible to PyTorch

## Supported Ryzen Models (iGPU)

The script contains special hints for common laptop APUs:

| CPU Model       | iGPU          | Typical gfx Target | HSA_OVERRIDE Hint      |
|-----------------|---------------|--------------------|------------------------|
| Ryzen 7 7735HS  | Radeon 680M   | gfx103x            | `10.3.0`               |
| Ryzen 9 6900HX  | Radeon 680M   | gfx103x            | `10.3.0`               |
| Ryzen 7 8845HS  | Radeon 780M   | gfx1103            | `11.0.0`               |
| Ryzen 7 8835H   | Radeon 780M   | gfx1103            | `11.0.0`               |
| Ryzen AI 9 370  | Radeon 890M   | gfx1150            | `11.0.0` or `11.5.0`   |
| Ryzen AI 9 470  | Radeon 890M   | gfx1150            | `11.0.0` or `11.5.0`   |

Example (manual):

```bash
export HSA_OVERRIDE_GFX_VERSION=11.0.0
./install.sh
```

Automatisch nach der Installation:

```bash
source ./activate_env.sh
```

Vollständige Kompatibilitätsliste (Instinct, Radeon PRO, RX, Ryzen APUs):

**[COMPATIBILITY.md](COMPATIBILITY.md)**

## GPU / iGPU Detection & Kernel Modules

At the start the script tries to identify your AMD hardware, checks whether the `amdgpu` and `amdkfd` modules are loaded, and reports important parameters (ppfeaturemask, gpu_recovery, etc.).

For details on the modules, parameters, and recommended settings for Ryzen APUs / CachyOS see:

**[DRIVER_MODULES.md](DRIVER_MODULES.md)**

## System ROCm / Driver Installation (optional)

```bash
INSTALL_ROCM=1 ./install.sh
```

### Behavior by distribution

| Distribution          | Action |
|-----------------------|--------|
| **CachyOS / Arch**    | Prints recommended `pacman` / AUR commands |
| **Ubuntu 26.04**      | Tries `sudo apt install -y rocm` |
| **Ubuntu 24.04 / others** | Prints steps for `amdgpu-install` |

**CachyOS example:**

```bash
sudo pacman -Syu
sudo pacman -S rocm-core rocm-hip-runtime rocminfo rocm-smi-lib
# or for more packages: paru -S rocm-hip-sdk
```

Always add your user to the groups and re-login (or let `prepare_os.sh` do it):

```bash
sudo usermod -a -G render,video $USER
```

## AMD GPU Virtualisierung

Für VFIO-Passthrough, SR-IOV (Instinct), Container und ROCm in VMs siehe:

**[VIRTUALIZATION.md](VIRTUALIZATION.md)**

## Performance Tuning

Praktische Tipps für maximale Performance (HSA_OVERRIDE, Kernel-Parameter, Container vs. VFIO, Monitoring):

**[PERFORMANCE.md](PERFORMANCE.md)**

## Kernel-Optimierungen

Environment-Variablen, PyTorch TunableOp, MIOpen-Tuning und Profiling:

**[KERNEL_OPTIMIZATIONS.md](KERNEL_OPTIMIZATIONS.md)**

## Profiling mit rocprofv3

Ausführliche Anleitung zu Kernel-Statistiken, Traces, Perfetto und Hardware-Countern:

**[PROFILING.md](PROFILING.md)**

### Perfetto-Visualisierung

Timeline-basierte Analyse mit Perfetto UI:

**[PERFETTO.md](PERFETTO.md)**

## Systemdiagnose

Tools und Workflows zur Prüfung, ob ROCm und die GPU korrekt funktionieren (`rocminfo`, `rocm-smi`, `amd-smi`, …):

**[DIAGNOSTICS.md](DIAGNOSTICS.md)**

## CachyOS & Zen4 Tuning

Spezifische Optimierungen für CachyOS und Zen4/Zen5 CPUs:

- **[CACHYOS.md](CACHYOS.md)** – Optimized Repositories (znver4), Kernel (ThinLTO/AutoFDO/BORE), ROCm-Pakete
- **[ZEN4.md](ZEN4.md)** – Zen4-spezifisches Tuning und znver4-Repository
- **[AMD_PSTATE.md](AMD_PSTATE.md)** – AMD P-State Autonomous Mode (`amd_pstate=active`) und EPP

## Usage after install

```bash
source ./activate_env.sh
# or manually:
# source venv/bin/activate
python -c "import torch; print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'No GPU')"
```

## Debugging

### Debug mode

```bash
DEBUG=1 ./install.sh
```

### Useful environment variables

| Variable       | Default     | Description                                      |
|----------------|-------------|--------------------------------------------------|
| `DEBUG`        | `0`         | Set to `1` for verbose tracing                   |
| `INSTALL_ROCM` | `0`         | Set to `1` to attempt system ROCm installation   |
| `VENV_DIR`     | `./venv`    | Path of the virtual environment                  |
| `PYTHON`       | `python3`   | Python interpreter to use                        |
| `LOG_FILE`     | `install.log` | Log file location                              |

### Common problems

- **`python3-venv` missing** (Ubuntu) → `sudo apt install python3-venv` (or run `./prepare_os.sh`)
- **No GPU detected** → Check ROCm, groups (`video`, `render`), and `HSA_OVERRIDE_GFX_VERSION`
- **amdgpu / amdkfd not loaded** → See [DRIVER_MODULES.md](DRIVER_MODULES.md)
- **iGPU not working** → See the Ryzen table above and DRIVER_MODULES.md
- **After driver install** → Reboot and re-check with `rocminfo`

## Notes

- CachyOS / Arch users benefit from the latest kernels and official ROCm packages.
- On Ubuntu 26.04 you can often just use `sudo apt install rocm`.
- Always activate the venv before running your workloads (prefer `source ./activate_env.sh`).
- See [Todo.md](Todo.md) for planned improvements.

## License

MIT
