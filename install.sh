#!/usr/bin/env bash
# AMD ROCm Virtual Environment Installer
# Creates a clean Python venv and installs ROCm-enabled PyTorch
#
# Usage:
#   ./install.sh
#   VENV_DIR=~/my-env PYTHON=python3.12 ./install.sh

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
VENV_DIR="${VENV_DIR:-./venv}"
PYTHON="${PYTHON:-python3}"
LOG_FILE="${LOG_FILE:-install.log}"

# Colors (safe even if terminal does not support them)
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()   { echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE" >&2; }
error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" >&2; }
success(){ echo -e "${GREEN}[OK]${NC} $*" | tee -a "$LOG_FILE"; }

cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    error "Installation failed with exit code $exit_code"
    error "Check the log: $LOG_FILE"
    error "You can remove a broken venv with: rm -rf \"$VENV_DIR\""
  fi
  exit $exit_code
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# Start
# ---------------------------------------------------------------------------
: > "$LOG_FILE"   # truncate log
log "=== AMD ROCm Virtual Environment Installer ==="
log "Log file: $LOG_FILE"
log "Target venv: $VENV_DIR"
log "Python binary: $PYTHON"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  error "$PYTHON not found in PATH."
  error "Install it with: sudo apt install python3 python3-venv python3-pip"
  exit 1
fi

PY_VERSION=$("$PYTHON" --version 2>&1 || true)
log "Detected: $PY_VERSION"

# Check that the venv module is available
if ! "$PYTHON" -c "import venv" >/dev/null 2>&1; then
  error "Python venv module is missing."
  error "On Ubuntu/Debian run: sudo apt install python3-venv"
  exit 1
fi

# Optional: warn if no ROCm tools are visible
if ! command -v rocminfo >/dev/null 2>&1 && ! command -v rocm-smi >/dev/null 2>&1; then
  warn "Neither rocminfo nor rocm-smi found. ROCm may not be installed on the host."
  warn "PyTorch may still work if the wheels bundle the necessary runtime, but GPU detection can fail."
fi

# Rough disk space check (at least ~3 GB free recommended)
if command -v df >/dev/null 2>&1; then
  FREE_KB=$(df -k . | awk 'NR==2 {print $4}')
  if [[ -n "$FREE_KB" && "$FREE_KB" -lt 3000000 ]]; then
    warn "Less than ~3 GB free disk space in current directory. Installation may fail."
  fi
fi

# ---------------------------------------------------------------------------
# Create / reuse virtual environment
# ---------------------------------------------------------------------------
if [[ -d "$VENV_DIR" ]]; then
  log "Virtual environment already exists at $VENV_DIR – reusing."
  if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
    error "Directory exists but does not look like a valid venv (missing bin/activate)."
    error "Remove it first: rm -rf \"$VENV_DIR\""
    exit 1
  fi
else
  log "Creating virtual environment in $VENV_DIR ..."
  if ! "$PYTHON" -m venv "$VENV_DIR" >>"$LOG_FILE" 2>&1; then
    error "Failed to create virtual environment."
    exit 1
  fi
  success "Virtual environment created."
fi

# ---------------------------------------------------------------------------
# Activate
# ---------------------------------------------------------------------------
# shellcheck disable=SC1091
if ! source "$VENV_DIR/bin/activate"; then
  error "Failed to activate virtual environment."
  exit 1
fi
log "Activated venv (Python: $(python --version 2>&1))"

# ---------------------------------------------------------------------------
# Upgrade pip
# ---------------------------------------------------------------------------
log "Upgrading pip, wheel and setuptools..."
if ! python -m pip install --upgrade pip wheel setuptools >>"$LOG_FILE" 2>&1; then
  error "Failed to upgrade pip."
  exit 1
fi
success "pip upgraded."

# ---------------------------------------------------------------------------
# Install ROCm PyTorch
# ---------------------------------------------------------------------------
log "Installing ROCm-enabled PyTorch (this can take several minutes)..."

install_torch() {
  local index_url="$1"
  log "Trying index: $index_url"
  if python -m pip install torch torchvision torchaudio --index-url "$index_url" >>"$LOG_FILE" 2>&1; then
    return 0
  else
    warn "Install from $index_url failed."
    return 1
  fi
}

INSTALLED=0
# Try newer ROCm indexes first, then fall back
for INDEX in \
  "https://download.pytorch.org/whl/rocm6.2" \
  "https://download.pytorch.org/whl/rocm6.1" \
  "https://download.pytorch.org/whl/rocm6.0"; do
  if install_torch "$INDEX"; then
    INSTALLED=1
    break
  fi
done

if [[ $INSTALLED -eq 0 ]]; then
  error "All PyTorch ROCm index attempts failed."
  error "Possible causes: network issues, unsupported GPU architecture, or index downtime."
  error "Check $LOG_FILE for details."
  exit 1
fi
success "PyTorch installed."

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------
log "=== Verification ==="
python - << 'EOF' 2>&1 | tee -a "$LOG_FILE"
import sys
try:
    import torch
    print(f"PyTorch version: {torch.__version__}")
    print(f"HIP available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"Device: {torch.cuda.get_device_name(0)}")
        print(f"Device count: {torch.cuda.device_count()}")
    else:
        print("Warning: No AMD GPU detected by PyTorch.")
        print("Check ROCm installation, user groups (video/render), and permissions.")
except Exception as e:
    print(f"ERROR during verification: {e}")
    sys.exit(1)
EOF

if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
  error "Verification script failed."
  exit 1
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
success "Installation completed successfully."
log ""
log "Activate the environment with:"
log "  source \"$VENV_DIR/bin/activate\""
log ""
log "You can now install additional packages inside the venv, e.g.:"
log "  pip install transformers accelerate"
log ""
log "Full log saved to: $LOG_FILE"
