#!/usr/bin/env bash
# activate_env.sh – Activate the ROCm virtual environment and set HSA_OVERRIDE automatically
#
# Usage:
#   source ./activate_env.sh
#   # or
#   . ./activate_env.sh
#
# It will:
#   1. Source the venv (default: ./venv)
#   2. Detect common Ryzen iGPUs via lspci and set HSA_OVERRIDE_GFX_VERSION
#   3. Print a short status

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
VENV_DIR="${VENV_DIR:-./venv}"

# Colors (optional)
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  GREEN='' YELLOW='' BLUE='' NC=''
fi

log()  { echo -e "${BLUE}[activate_env]${NC} $*"; }
warn() { echo -e "${YELLOW}[activate_env]${NC} $*"; }
ok()   { echo -e "${GREEN}[activate_env]${NC} $*"; }

# ---------------------------------------------------------------------------
# Activate venv
# ---------------------------------------------------------------------------
if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
  warn "Virtual environment not found at $VENV_DIR"
  warn "Run ./install.sh first or set VENV_DIR."
  return 1 2>/dev/null || exit 1
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
ok "Activated venv: $VENV_DIR"

# ---------------------------------------------------------------------------
# Auto-detect HSA_OVERRIDE for common Ryzen iGPUs
# ---------------------------------------------------------------------------
if [[ -z "${HSA_OVERRIDE_GFX_VERSION:-}" ]]; then
  if command -v lspci >/dev/null 2>&1; then
    local lspci_out
    lspci_out=$(lspci -nn | grep -iE 'vga|3d|display' | grep -i '1002:' || true)

    if echo "$lspci_out" | grep -qiE 'Radeon.*890M|880M|gfx1150|Strix'; then
      export HSA_OVERRIDE_GFX_VERSION=11.0.0
      log "Detected Ryzen AI 300 iGPU (890M) → HSA_OVERRIDE_GFX_VERSION=11.0.0"
    elif echo "$lspci_out" | grep -qiE 'Radeon.*780M|760M|gfx1103|Phoenix|Hawk'; then
      export HSA_OVERRIDE_GFX_VERSION=11.0.0
      log "Detected Ryzen 7000/8000 iGPU (780M) → HSA_OVERRIDE_GFX_VERSION=11.0.0"
    elif echo "$lspci_out" | grep -qiE 'Radeon.*680M|660M|Rembrandt|gfx103'; then
      export HSA_OVERRIDE_GFX_VERSION=10.3.0
      log "Detected Ryzen 6000/7735 iGPU (680M) → HSA_OVERRIDE_GFX_VERSION=10.3.0"
    else
      log "No common Ryzen iGPU detected that requires HSA_OVERRIDE (or discrete GPU)."
    fi
  else
    warn "lspci not found – cannot auto-detect HSA_OVERRIDE."
  fi
else
  log "HSA_OVERRIDE_GFX_VERSION already set to: $HSA_OVERRIDE_GFX_VERSION"
fi

# ---------------------------------------------------------------------------
# Status
# ---------------------------------------------------------------------------
echo
if [[ -n "${HSA_OVERRIDE_GFX_VERSION:-}" ]]; then
  ok "HSA_OVERRIDE_GFX_VERSION=$HSA_OVERRIDE_GFX_VERSION"
else
  log "HSA_OVERRIDE_GFX_VERSION is not set (may be fine for discrete GPUs)."
fi

ok "Ready. You can now run Python / PyTorch."
echo
