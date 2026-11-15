# AMD Virtual Environment Installer

Simple install script to set up a clean Python virtual environment with **ROCm-enabled PyTorch** on AMD GPUs.

This is useful when you want an isolated environment for ML/AI workloads (ComfyUI, Ollama, custom training, etc.) without polluting the system Python.

## Prerequisites

- AMD GPU with ROCm support (Radeon RX 6000/7000/9000 series or Instinct)
- Ubuntu 22.04 / 24.04 / 26.04 (or similar Debian-based)
- ROCm installed on the host (or use the system packages)
- Python 3.10+

```bash
# Quick check
rocminfo
# or
python3 --version
```

## Quick Start

```bash
git clone https://github.com/siteoperator/amd-virt-env-installer.git
cd amd-virt-env-installer
chmod +x install.sh
./install.sh
```

The script will:
1. Detect your AMD GPU / iGPU (via `rocminfo`, `lspci` and `rocm-smi`)
2. Create a virtual environment (`./venv` by default)
3. Upgrade pip
4. Install the latest stable ROCm PyTorch wheels
5. Verify that the GPU is visible to PyTorch

## GPU / iGPU Detection

At the start the script tries to identify your AMD hardware:

- **rocminfo** (preferred) – shows Marketing Name, gfx target, Device Type
- **lspci** – lists AMD PCI devices (vendor `1002`) and gives a rough classification (discrete RDNA2/3/4 vs. iGPU)
- **rocm-smi** – product name if available

Example output:

```
[INFO] === Detecting AMD GPUs / iGPUs ===
[INFO] AMD PCI devices (vendor 1002):
01:00.0 VGA compatible controller [0300]: Advanced Micro Devices, Inc. [AMD/ATI] Navi 32 [Radeon RX 7700 XT] [1002:747e]
[INFO] Detected: Likely discrete GPU (RDNA3/RDNA4 / RX 7000/9000 series)
```

This helps you choose the correct ROCm version or decide whether `HSA_OVERRIDE_GFX_VERSION` is needed (especially for iGPUs).

## Usage after install

```bash
source venv/bin/activate
python -c "import torch; print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'No GPU')"
```

## Debugging

The installer includes several built-in debugging features.

### Normal run

```bash
./install.sh
```

All output is written to `install.log` in the current directory.

### Debug mode (recommended when something fails)

```bash
DEBUG=1 ./install.sh
```

This enables:
- Full command tracing (`set -x`) with file, line number and function name
- Extra `[DEBUG]` messages
- Complete environment dump if an error occurs

Example with custom settings:

```bash
DEBUG=1 VENV_DIR=~/rocm-env PYTHON=python3.12 ./install.sh
```

### What you get on errors

When a command fails the script shows:
- Exact line number
- Function name
- The failing command
- Exit code
- Path to the log file
- Suggestion how to remove a broken virtual environment

Example error output:

```
[ERROR] Failed at line 142 in function 'install_torch'
[ERROR] Command: python -m pip install torch torchvision torchaudio --index-url ...
[ERROR] Exit code: 1
[ERROR] Check the full log: install.log
```

### Useful environment variables

| Variable   | Default   | Description                          |
|------------|-----------|--------------------------------------|
| `DEBUG`    | `0`       | Set to `1` for verbose tracing       |
| `VENV_DIR` | `./venv`  | Path of the virtual environment      |
| `PYTHON`   | `python3` | Python interpreter to use            |
| `LOG_FILE` | `install.log` | Log file location                 |

### Common problems

- **`python3-venv` missing** → `sudo apt install python3-venv`
- **No GPU detected** → Check ROCm installation, user groups (`video`, `render`) and permissions
- **Disk space** → At least ~3 GB free recommended
- **Network issues** → The script tries multiple PyTorch ROCm indexes automatically
- **iGPU not working** → Often needs a specific ROCm version or `HSA_OVERRIDE_GFX_VERSION`

## Customization

Edit `install.sh` to change:
- Virtual environment path
- Specific ROCm / PyTorch versions
- Extra packages (e.g. `transformers`, `accelerate`, `comfyui` dependencies)

## Notes

- On Ubuntu 26.04 you can often just use `sudo apt install rocm` for the system packages.
- For the newest ROCm versions, the official AMD wheel indexes are preferred.
- Always activate the venv before running your workloads.

## License

MIT
