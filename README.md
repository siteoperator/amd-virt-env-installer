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
1. Create a virtual environment (`./venv` by default)
2. Upgrade pip
3. Install the latest stable ROCm PyTorch wheels
4. Verify that the GPU is visible to PyTorch

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
