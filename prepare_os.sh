#!/usr/bin/env bash
# prepare_os.sh – Base system preparation for AMD ROCm Virtual Environment Installer
# Installs the minimum packages needed on a blank Ubuntu or CachyOS/Arch system
# before running install.sh
#
# Usage:
#   chmod +x prepare_os.sh
#   ./prepare_os.sh
#
# What it installs:
#   Ubuntu:  python3 python3-venv python3-pip pciutils git
#   CachyOS: python pciutils git (+ full system update)

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
# Install base packages
# ---------------------------------------------------------------------------
install_base_packages() {
  if ! command -v sudo >/dev/null 2>&1; then
    error "sudo is not installed. Please install sudo first or run as root."
    exit 1
  fi

  if [[ "$DISTRO" == "ubuntu" ]]; then
    log "Preparing Ubuntu system..."
    log "Updating package lists and installing base packages:"
    log "  python3 python3-venv python3-pip pciutils git"
    sudo apt update
    sudo apt install -y python3 python3-venv python3-pip pciutils git
    success "Ubuntu base packages installed."

  elif [[ "$DISTRO" == "arch" ]]; then
    log "Preparing CachyOS / Arch system..."
    log "Updating system and installing base packages:"
    log "  python pciutils git"
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm --needed python pciutils git
    success "CachyOS/Arch base packages installed."

  else
    warn "Unknown distribution: $DISTRO"
    warn "Please install the following packages manually:"
    warn "  - Python 3 + venv module"
    warn "  - pciutils (for lspci)"
    warn "  - git"
    exit 1
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
  log "2. Add your user to the required groups and re-login:"
  log "     sudo usermod -a -G render,video $USER"
  log "     # then log out and back in (or reboot)"
  log ""
  log "3. Run the main installer:"
  log "     ./install.sh"
  log ""
  log "4. For many Ryzen iGPUs set HSA_OVERRIDE_GFX_VERSION, e.g.:"
  log "     export HSA_OVERRIDE_GFX_VERSION=11.0.0"
  echo
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
log "=== prepare_os.sh – Base system preparation ==="
detect_distro
install_base_packages
print_next_steps
success "System preparation finished."
