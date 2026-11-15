#!/usr/bin/env bash
# AMD ROCm Virtual Environment Installer
# Creates a clean Python venv and installs ROCm-enabled PyTorch
# Optionally installs the system-wide ROCm stack / amdgpu driver
#
# Usage:
#   ./install.sh
#   DEBUG=1 ./install.sh
#   INSTALL_ROCM=1 ./install.sh          # also try to install system ROCm (requires sudo)
#   VENV_DIR=~/my-env PYTHON=python3.12 ./install.sh
#
# Features:
#   - AMD GPU / iGPU detection
#   - Optional system ROCm install (Ubuntu 24.04 / 26.04 aware)
#   - Robust venv + PyTorch ROCm wheels
#   - DEBUG mode, detailed logging, error context

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration & Debug mode
# ---------------------------------------------------------------------------
VENV_DIR="${VENV_DIR:-./venv}"
PYTHON="${PYTHON:-python3}"
LOG_FILE="${LOG_FILE:-install.log}"
DEBUG="${DEBUG:-0}"
INSTALL_ROCM="${INSTALL_ROCM:-0}"   # set to 1 to attempt system ROCm install

# Enable full tracing when DEBUG=1
if [[ "$DEBUG" == "1" ]]; then
  set -x
  export PS4='+ ${BASH_SOURCE[0]}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
fi

# Colors
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  MAGENTA='\033[0;35m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' NC=''
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()    { echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE" >&2; }
error()  { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" >&2; }
success(){ echo -e "${GREEN}[OK]${NC} $*" | tee -a "$LOG_FILE"; }
debug()  { [[ "$DEBUG" == "1" ]] && echo -e "${MAGENTA}[DEBUG]${NC} $*" | tee -a "$LOG_FILE" >&2 || true; }

on_error() {
  local exit_code=$?
  local line_no=${1:-unknown}
  local func_name=${2:-main}
  local cmd=${3:-unknown}

  error "Failed at line $line_no in function '${func_name}'"
  error "Command: $cmd"
  error "Exit code: $exit_code"

  if [[ "$DEBUG" == "1" ]]; then
    error "--- Environment dump (DEBUG mode) ---"
    env | sort | tee -a "$LOG_FILE" >&2 || true
    error "--- End environment dump ---"
  fi

  error "Check the full log: $LOG_FILE"
  error "You can remove a broken venv with: rm -rf \"$VENV_DIR\""
  exit $exit_code
}

trap 'on_error ${BASH_LINENO[0]} ${FUNCNAME[1]:-main} "$BASH_COMMAND"' ERR

cleanup() {
  local exit_code=$?
  if [[ $exit_code -ne 0 ]]; then
    error "Installation aborted (exit $exit_code)."
  fi
  exit $exit_code
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# AMD GPU / iGPU Detection
# ---------------------------------------------------------------------------
detect_amd_gpus() {
  local gpus_found=0
  log "=== Detecting AMD GPUs / iGPUs ==="

  if command -v rocminfo >/dev/null 2>&1; then
    log "Using rocminfo for detailed agent info..."
    local agents
    agents=$(rocminfo 2>/dev/null | grep -E "Marketing Name:|Name:|Device Type:|gfx" | head -40 || true)
    if [[ -n "$agents" ]]; then
      echo "$agents" | tee -a "$LOG_FILE"
      gpus_found=1
    fi
  fi

  if command -v lspci >/dev/null 2>&1; then
    local lspci_out
    lspci_out=$(lspci -nn | grep -iE 'vga|3d|display' | grep -i '1002:' || true)
    if [[ -n "$lspci_out" ]]; then
      log "AMD PCI devices (vendor 1002):"
      echo "$lspci_out" | tee -a "$LOG_FILE"
      gpus_found=1

      if echo "$lspci_out" | grep -qiE 'Radeon.*RX [7-9]|Navi [3-4]|gfx11|gfx12'; then
        log "Detected: Likely discrete GPU (RDNA3/RDNA4 / RX 7000/9000 series)"
      elif echo "$lspci_out" | grep -qiE 'Radeon.*RX 6|Navi 2|gfx10'; then
        log "Detected: Likely discrete GPU (RDNA2 / RX 6000 series)"
      elif echo "$lspci_out" | grep -qiE 'Radeon.*780M|760M|680M|Phoenix|Rembrandt|gfx1103|gfx1036'; then
        log "Detected: Likely integrated GPU (iGPU / APU)"
        warn "iGPUs often need specific ROCm versions or HSA_OVERRIDE_GFX_VERSION."
      else
        log "Detected: AMD GPU (exact model classification incomplete)"
      fi
    else
      warn "No AMD GPU found via lspci."
    fi
  else
    warn "lspci not available. Install pciutils for better detection."
  fi

  if command -v rocm-smi >/dev/null 2>&1; then
    log "rocm-smi product info:"
    rocm-smi --showproductname 2>/dev/null | head -20 | tee -a "$LOG_FILE" || true
    gpus_found=1
  fi

  if [[ $gpus_found -eq 0 ]]; then
    warn "No AMD GPU / iGPU could be detected."
    warn "The installer will continue, but ROCm/PyTorch may fall back to CPU."
    warn "Make sure the amdgpu driver is loaded and the user is in groups 'render' and 'video'."
  else
    success "AMD GPU detection finished."
  fi
  log ""
}

# ---------------------------------------------------------------------------
# Optional System ROCm Installation
# ---------------------------------------------------------------------------
install_rocm_system() {
  if [[ "$INSTALL_ROCM" != "1" ]]; then
    log "Skipping system ROCm install (set INSTALL_ROCM=1 to enable)."
    return 0
  fi

  log "=== System ROCm / amdgpu Installation ==="
  warn "This step requires sudo and may change system packages."
  warn "A reboot is usually required afterwards."

  if ! command -v sudo >/dev/null 2>&1; then
    error "sudo not found. Cannot install system ROCm."
    return 1
  fi

  # Detect Ubuntu version
  local ubuntu_ver=""
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    ubuntu_ver="${VERSION_ID:-}"
    log "Detected OS: ${NAME:-Unknown} ${ubuntu_ver}"
  fi

  if [[ "$ubuntu_ver" == "26.04" ]]; then
    log "Ubuntu 26.04 detected – trying native apt install rocm..."
    if sudo apt update && sudo apt install -y rocm; then
      success "ROCm installed via Ubuntu packages."
      log "You may still want to add yourself to groups:"
      log "  sudo usermod -a -G render,video $USER"
      log "Then log out and back in (or reboot)."
    else
      warn "apt install rocm failed. Falling back to manual guidance."
    fi
  else
    log "Ubuntu $ubuntu_ver (or other) – recommending AMD amdgpu-install method."
    log ""
    log "Recommended steps (run manually or review carefully):"
    log "  1. Download amdgpu-install for your Ubuntu version from:"
    log "     https://repo.radeon.com/amdgpu-install/"
    log "  2. Example for Ubuntu 24.04 (noble):"
    log "     wget https://repo.radeon.com/amdgpu-install/7.2.4/ubuntu/noble/amdgpu-install_7.2.4.70204-1_all.deb"
    log "     sudo apt install ./amdgpu-install_*.deb"
    log "  3. Install ROCm:"
    log "     sudo amdgpu-install -y --usecase=rocm"
    log "  4. Add user to groups and reboot:"
    log "     sudo usermod -a -G render,video $USER"
    log "     sudo reboot"
    log ""
    warn "Automatic amdgpu-install is not executed by default for safety."
    warn "Set INSTALL_ROCM=1 and review the log, or run the commands above."
  fi

  # Common post-steps
  if ! groups "$USER" | grep -qE 'render|video'; then
    warn "Current user is not in 'render' or 'video' group."
    warn "Run: sudo usermod -a -G render,video $USER   (then re-login)"
  fi

  log "System ROCm step finished."
  log ""
}

# ---------------------------------------------------------------------------
# Start
# ---------------------------------------------------------------------------
: > "$LOG_FILE"
log "=== AMD ROCm Virtual Environment Installer ==="
log "Log file: $LOG_FILE"
log "Target venv: $VENV_DIR"
log "Python binary: $PYTHON"
log "INSTALL_ROCM=$INSTALL_ROCM"
debug "Debug mode is ON (set -x enabled, full tracing)"
debug "Bash version: $BASH_VERSION"

detect_amd_gpus
install_rocm_system

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
debug "Python path: $(command -v "$PYTHON")"

if ! "$PYTHON" -c "import venv" >/dev/null 2>&1; then
  error "Python venv module is missing."
  error "On Ubuntu/Debian run: sudo apt install python3-venv"
  exit 1
fi

if ! command -v rocminfo >/dev/null 2>&1 && ! command -v rocm-smi >/dev/null 2>&1; then
  warn "Neither rocminfo nor rocm-smi found. ROCm may not be installed on the host."
  warn "PyTorch may still work if the wheels bundle the necessary runtime, but GPU detection can fail."
fi

if command -v df >/dev/null 2>&1; then
  FREE_KB=$(df -k . | awk 'NR==2 {print $4}')
  debug "Free disk space: ${FREE_KB} KB"
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
debug "VIRTUAL_ENV=$VIRTUAL_ENV"

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
  debug "Running: python -m pip install torch torchvision torchaudio --index-url $index_url"
  if python -m pip install torch torchvision torchaudio --index-url "$index_url" >>"$LOG_FILE" 2>&1; then
    return 0
  else
    warn "Install from $index_url failed."
    return 1
  fi
}

INSTALLED=0
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
if [[ "$DEBUG" == "1" ]]; then
  log "Debug mode was enabled. Full command trace is in the log."
fi
if [[ "$INSTALL_ROCM" == "1" ]]; then
  log "System ROCm installation was requested. Check above for results and reboot if needed."
fi
