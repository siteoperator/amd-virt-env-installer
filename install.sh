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
# Supported distributions:
#   - Ubuntu 22.04 / 24.04 / 26.04
#   - CachyOS / Arch Linux (and derivatives)
#
# Features:
#   - AMD GPU / iGPU detection (including common Ryzen APUs)
#   - Optional system ROCm install (Ubuntu + CachyOS/Arch aware)
#   - Robust venv + PyTorch ROCm wheels
#   - DEBUG mode, detailed logging, error context
#   - Pre-flight checks for groups, /dev/kfd permissions and HSA_OVERRIDE

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
# Distro Detection
# ---------------------------------------------------------------------------
detect_distro() {
  DISTRO="unknown"
  DISTRO_VER=""
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    case "${ID:-}" in
      ubuntu) DISTRO="ubuntu"; DISTRO_VER="${VERSION_ID:-}" ;;
      cachyos|arch|endeavouros|manjaro) DISTRO="arch"; DISTRO_VER="${VERSION_ID:-rolling}" ;;
      *) DISTRO="${ID:-unknown}" ;;
    esac
  fi
  log "Detected distribution: $DISTRO ${DISTRO_VER}"
}

# ---------------------------------------------------------------------------
# Pre-flight: Groups, /dev/kfd, HSA_OVERRIDE
# ---------------------------------------------------------------------------
check_permissions_and_groups() {
  log "=== Pre-flight: Groups, /dev/kfd and HSA_OVERRIDE ==="

  # 1. Groups render + video
  local user_groups
  user_groups=$(groups "$USER" 2>/dev/null || true)
  local missing_groups=()
  for g in render video; do
    if ! echo "$user_groups" | grep -qw "$g"; then
      missing_groups+=("$g")
    fi
  done

  if [[ ${#missing_groups[@]} -gt 0 ]]; then
    warn "User '$USER' is missing groups: ${missing_groups[*]}"
    warn "This is the most common reason for 'no GPU in rocminfo' or permission errors."
    warn "Fix with:"
    warn "  sudo usermod -a -G render,video $USER"
    warn "Then **log out and log back in** (or reboot)."
  else
    success "User is in groups 'render' and 'video'."
  fi

  # 2. /dev/kfd permissions
  if [[ -e /dev/kfd ]]; then
    if [[ -r /dev/kfd && -w /dev/kfd ]]; then
      success "/dev/kfd is readable and writable."
    else
      warn "Permission denied on /dev/kfd (or not readable/writable)."
      warn "Current permissions:"
      ls -l /dev/kfd | tee -a "$LOG_FILE" || true
      warn "Fix: ensure user is in 'render' and 'video', then re-login."
      warn "Also check udev rules (usually provided by the ROCm packages)."
    fi
  else
    warn "/dev/kfd does not exist. amdgpu / amdkfd driver may not be loaded."
    warn "Try: lsmod | grep -E 'amdgpu|amdkfd'"
  fi

  # 3. HSA_OVERRIDE_GFX_VERSION hint
  if [[ -n "${HSA_OVERRIDE_GFX_VERSION:-}" ]]; then
    log "HSA_OVERRIDE_GFX_VERSION is set to: $HSA_OVERRIDE_GFX_VERSION"
  else
    log "HSA_OVERRIDE_GFX_VERSION is not set."
    warn "Many Ryzen iGPUs (680M, 780M, 890M, …) need this variable."
    warn "Examples:"
    warn "  export HSA_OVERRIDE_GFX_VERSION=10.3.0   # 680M / 7735HS / 6900HX"
    warn "  export HSA_OVERRIDE_GFX_VERSION=11.0.0   # 780M / 8845HS / 8835H / AI 370"
    warn "  export HSA_OVERRIDE_GFX_VERSION=11.5.0   # some 890M"
  fi

  log ""
}

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
      if echo "$agents" | grep -q "Device Type:.*GPU"; then
        gpus_found=1
        success "rocminfo sees at least one GPU agent."
      else
        warn "rocminfo is available but shows **no GPU agent**."
        warn "Most common causes: missing groups (render/video) or driver not loaded."
      fi
    else
      warn "rocminfo produced no useful output."
    fi
  else
    warn "rocminfo not found. Install ROCm packages for better diagnostics."
  fi

  if command -v lspci >/dev/null 2>&1; then
    local lspci_out
    lspci_out=$(lspci -nn | grep -iE 'vga|3d|display' | grep -i '1002:' || true)
    if [[ -n "$lspci_out" ]]; then
      log "AMD PCI devices (vendor 1002):"
      echo "$lspci_out" | tee -a "$LOG_FILE"
      gpus_found=1

      # Classification + Ryzen APU hints
      if echo "$lspci_out" | grep -qiE 'Radeon.*890M|880M|gfx1150|Strix'; then
        log "Detected: Ryzen AI 300 series iGPU (Radeon 890M / gfx1150)"
        warn "For AI 370 / AI 470 etc. try: export HSA_OVERRIDE_GFX_VERSION=11.0.0 or 11.5.0"
      elif echo "$lspci_out" | grep -qiE 'Radeon.*780M|760M|gfx1103|Phoenix|Hawk'; then
        log "Detected: Ryzen 7000/8000 series iGPU (Radeon 780M / gfx1103)"
        warn "For 8845HS / 8835H etc. often works with HSA_OVERRIDE_GFX_VERSION=11.0.0"
      elif echo "$lspci_out" | grep -qiE 'Radeon.*680M|660M|Rembrandt|gfx103'; then
        log "Detected: Ryzen 6000/7000 series iGPU (Radeon 680M)"
        warn "For 7735HS / 6900HX etc. try HSA_OVERRIDE_GFX_VERSION=10.3.0"
      elif echo "$lspci_out" | grep -qiE 'Radeon.*RX [7-9]|Navi [3-4]|gfx11|gfx12'; then
        log "Detected: Likely discrete GPU (RDNA3/RDNA4 / RX 7000/9000 series)"
      elif echo "$lspci_out" | grep -qiE 'Radeon.*RX 6|Navi 2|gfx10'; then
        log "Detected: Likely discrete GPU (RDNA2 / RX 6000 series)"
      else
        log "Detected: AMD GPU (exact model classification incomplete)"
        warn "iGPUs often need HSA_OVERRIDE_GFX_VERSION. Check rocminfo output."
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

  detect_distro

  if [[ "$DISTRO" == "arch" ]]; then
    log "CachyOS / Arch Linux detected."
    log "Recommended packages (official repos):"
    log "  sudo pacman -Syu"
    log "  sudo pacman -S rocm-core rocm-hip-runtime rocminfo rocm-smi-lib"
    log ""
    log "For the latest packages you can also use the AUR (e.g. with paru):"
    log "  paru -S rocm-hip-sdk"
    log ""
    warn "Automatic pacman install is not executed by default for safety."
    warn "Run the commands above, then re-login and re-run this script without INSTALL_ROCM."
  elif [[ "$DISTRO" == "ubuntu" && "$DISTRO_VER" == "26.04" ]]; then
    log "Ubuntu 26.04 detected – trying native apt install rocm..."
    if sudo apt update && sudo apt install -y rocm; then
      success "ROCm installed via Ubuntu packages."
    else
      warn "apt install rocm failed."
    fi
  else
    log "Ubuntu / Debian-based system detected."
    log "Recommended steps for Ubuntu 24.04 (noble):"
    log "  wget https://repo.radeon.com/amdgpu-install/7.2.4/ubuntu/noble/amdgpu-install_7.2.4.70204-1_all.deb"
    log "  sudo apt install ./amdgpu-install_*.deb"
    log "  sudo amdgpu-install -y --usecase=rocm"
    log ""
    warn "Automatic amdgpu-install is not executed by default for safety."
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

detect_distro
check_permissions_and_groups
detect_amd_gpus
install_rocm_system

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
if ! command -v "$PYTHON" >/dev/null 2>&1; then
  error "$PYTHON not found in PATH."
  if [[ "$DISTRO" == "arch" ]]; then
    error "Install it with: sudo pacman -S python"
  else
    error "Install it with: sudo apt install python3 python3-venv python3-pip"
  fi
  exit 1
fi

PY_VERSION=$("$PYTHON" --version 2>&1 || true)
log "Detected: $PY_VERSION"
debug "Python path: $(command -v "$PYTHON")"

if ! "$PYTHON" -c "import venv" >/dev/null 2>&1; then
  error "Python venv module is missing."
  if [[ "$DISTRO" == "arch" ]]; then
    error "On Arch/CachyOS the venv module is usually part of the python package."
  else
    error "On Ubuntu/Debian run: sudo apt install python3-venv"
  fi
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
        print("For many Ryzen iGPUs set HSA_OVERRIDE_GFX_VERSION before running.")
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
