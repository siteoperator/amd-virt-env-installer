#!/usr/bin/env bash
# prepare_os.sh – Base system preparation for AMD ROCm Virtual Environment Installer
# Installs the minimum packages needed on a blank Ubuntu or CachyOS/Arch system
# before running install.sh
#
# Also:
#   - Updates linux-firmware (important for GPU binding)
#   - Offers to add the current user to render + video groups
#
# Usage:
#   chmod +x prepare_os.sh
#   ./prepare_os.sh

set -euo pipefail

# Colors
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

log()    { echo -e "${BLUE}[INFO]${NC} $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()  { echo -e "${RED}[ERROR]${NC} $*"; }
success(){ echo -e "${GREEN}[OK]${NC} $*"; }

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
# Install base packages + firmware
# ---------------------------------------------------------------------------
install_base_packages() {
  if ! command -v sudo >/dev/null 2>&1; then
    error "sudo is not installed. Please install sudo first or run as root."
    exit 1
  fi

  if [[ "$DISTRO" == "ubuntu" ]]; then
    log "Preparing Ubuntu system..."
    log "Updating package lists and installing base packages + firmware:"
    log "  python3 python3-venv python3-pip pciutils git linux-firmware"
    sudo apt update
    sudo apt install -y python3 python3-venv python3-pip pciutils git linux-firmware
    success "Ubuntu base packages and firmware installed/updated."

  elif [[ "$DISTRO" == "arch" ]]; then
    log "Preparing CachyOS / Arch system..."
    log "Updating system and installing base packages + firmware:"
    log "  python pciutils git linux-firmware"
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm --needed python pciutils git linux-firmware
    success "CachyOS/Arch base packages and firmware installed/updated."

  else
    warn "Unknown distribution: $DISTRO"
    warn "Please install the following packages manually:"
    warn "  - Python 3 + venv module"
    warn "  - pciutils (for lspci)"
    warn "  - git"
    warn "  - linux-firmware"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Groups (render + video)
# ---------------------------------------------------------------------------
ensure_groups() {
  log "Checking user groups (render + video)..."
  local user_groups
  user_groups=$(groups "$USER" 2>/dev/null || true)
  local missing=()
  for g in render video; do
    if ! echo "$user_groups" | grep -qw "$g"; then
      missing+=("$g")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    warn "User '$USER' is missing groups: ${missing[*]}"
    warn "These groups are required for /dev/kfd and rocminfo."
    read -r -p "Add user to render and video groups now? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
      sudo usermod -a -G render,video "$USER"
      success "User added to render and video."
      warn "You **must log out and log back in** (or reboot) for the change to take effect."
    else
      warn "Skipped. You can run later: sudo usermod -a -G render,video $USER"
    fi
  else
    success "User is already in groups 'render' and 'video'."
  fi
}

# ---------------------------------------------------------------------------
# Summary / next steps
# ---------------------------------------------------------------------------
print_next_steps() {
  echo
  log "=== Next steps ==="
  log "1. (Optional) Install ROCm / amdgpu driver:"
  log "     INSTALL_ROCM=1 ./install.sh"
  log "   or follow the printed commands."
  log ""
  log "2. If groups were just added → **log out and log back in** (or reboot)."
  log ""
  log "3. Run the main installer:"
  log "     ./install.sh"
  log ""
  log "4. After installation, activate with automatic HSA_OVERRIDE:"
  log "     source ./activate_env.sh"
  echo
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
log "=== prepare_os.sh – Base system preparation ==="
detect_distro
install_base_packages
ensure_groups
print_next_steps
success "System preparation finished."
