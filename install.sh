#!/usr/bin/env bash
# AMD ROCm Virtual Environment Installer
# Creates a clean Python venv and installs ROCm-enabled PyTorch

set -euo pipefail

VENV_DIR="${VENV_DIR:-./venv}"
PYTHON="${PYTHON:-python3}"

echo "=== AMD ROCm Virtual Environment Installer ==="
echo

# Check Python
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  echo "Error: $PYTHON not found. Install python3 and python3-venv."
  exit 1
fi

echo "Using Python: $($PYTHON --version)"

# Create venv
if [[ -d "$VENV_DIR" ]]; then
  echo "Virtual environment already exists at $VENV_DIR – reusing."
else
  echo "Creating virtual environment in $VENV_DIR ..."
  "$PYTHON" -m venv "$VENV_DIR"
fi

# Activate
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

echo "Upgrading pip..."
pip install --upgrade pip wheel setuptools

echo
echo "Installing ROCm PyTorch (stable index)..."
echo "(This may take a few minutes)"

# Prefer AMD's official ROCm wheels when available; fall back to PyTorch's ROCm index
if pip install --dry-run torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.2 >/dev/null 2>&1; then
  pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.2
else
  echo "Falling back to latest available ROCm wheels..."
  pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.1
fi

echo
echo "=== Verification ==="
python - << 'EOF'
import torch
print(f"PyTorch version: {torch.__version__}")
print(f"HIP available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"Device: {torch.cuda.get_device_name(0)}")
    print(f"Device count: {torch.cuda.device_count()}")
else:
    print("Warning: No AMD GPU detected by PyTorch. Check ROCm installation and permissions.")
EOF

echo
echo "Done! Activate the environment with:"
echo "  source $VENV_DIR/bin/activate"
echo
echo "You can now install additional packages (transformers, accelerate, etc.) inside the venv."
