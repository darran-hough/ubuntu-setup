#!/usr/bin/env bash
# ==============================================================================
#  ██████╗  █████╗ ███╗   ███╗██╗███╗   ██╗ ██████╗
# ██╔════╝ ██╔══██╗████╗ ████║██║████╗  ██║██╔════╝
# ██║  ███╗███████║██╔████╔██║██║██╔██╗ ██║██║  ███╗
# ██║   ██║██╔══██║██║╚██╔╝██║██║██║╚██╗██║██║   ██║
# ╚██████╔╝██║  ██║██║ ╚═╝ ██║██║██║ ╚████║╚██████╔╝
#  ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝
#
#  ███╗   ███╗███████╗██████╗ ██╗ █████╗     ██████╗ ███████╗ █████╗ ███████╗████████╗
#  ████╗ ████║██╔════╝██╔══██╗██║██╔══██╗    ██╔══██╗██╔════╝██╔══██╗██╔════╝╚══██╔══╝
#  ██╔████╔██║█████╗  ██║  ██║██║███████║    ██████╔╝█████╗  ███████║███████╗   ██║
#  ██║╚██╔╝██║██╔══╝  ██║  ██║██║██╔══██║    ██╔══██╗██╔══╝  ██╔══██║╚════██║   ██║
#  ██║ ╚═╝ ██║███████╗██████╔╝██║██║  ██║    ██████╔╝███████╗██║  ██║███████║   ██║
#  ╚═╝     ╚═╝╚══════╝╚═════╝ ╚═╝╚═╝  ╚═╝    ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝   ╚═╝
#
# ==============================================================================
# Ubuntu 24.04.4 LTS — Gaming & Media Beast Setup Script
# Version : 3.0.0
# Author  : Community Build
# Target  : Ubuntu 24.04.4 LTS (Noble Numbat)
# Features:
#   • Full hardware auto-detection (GPU / CPU / Audio / Network / Bluetooth)
#   • NVIDIA / AMD / Intel GPU driver auto-install
#   • Focusrite Scarlett auto-detection + alsa-scarlett-gui
#   • Gaming stack  : Steam, Lutris, Heroic, GameMode, MangoHud, Proton Plus
#   • Media stack   : VLC, MPV, Jellyfin, full codec support, OBS Studio
#   • Audio stack   : PipeWire, WirePlumber, JACK, Carla, full pro-audio support
#   • Windows apps  : WineHQ Staging, binfmt double-click, all VC++ & .NET runtimes
#                     DXVK, Bottles, 14 known-fix patches — Zorin OS grade compat
#   • System tweaks : CPU governor, swappiness, kernel params, udev rules
#   • Fully idiot-proof: colour output, spinners, safety checks, full logging
#
# COMPANION SCRIPT: Run windows-app-support.sh for the full Windows app layer
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

# ── Log file ──────────────────────────────────────────────────────────────────
LOG_FILE="/var/log/gaming-media-beast-setup.log"
SCRIPT_START=$(date '+%Y-%m-%d %H:%M:%S')

# ── Install tracking arrays ───────────────────────────────────────────────────
# Every component records itself into one of these three arrays.
# The final summary reads them to produce an accurate real-time report.
TRACK_INSTALLED=()   # Successfully installed (new)
TRACK_SKIPPED=()     # Already present — skipped
TRACK_FAILED=()      # Tried but failed
TRACK_DECLINED=()    # User said no when prompted

# ── Colour palette ────────────────────────────────────────────────────────────
RED='\033[0;31m';    LRED='\033[1;31m'
GREEN='\033[0;32m';  LGREEN='\033[1;32m'
YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m';   LCYAN='\033[1;36m'
MAGENTA='\033[0;35m';WHITE='\033[1;37m'
BOLD='\033[1m';      DIM='\033[2m'
NC='\033[0m'         # No Colour

# ── Spinner frames ────────────────────────────────────────────────────────────
SPINNER_FRAMES=('⣾' '⣽' '⣻' '⢿' '⡿' '⣟' '⣯' '⣷')
SPINNER_PID=""

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

show_log_path() {
    echo -e "  ${DIM}📋 Full log: ${CYAN}${LOG_FILE}${NC}"
}

print_banner() {
    clear
    echo -e "${LCYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║        🎮  UBUNTU GAMING & MEDIA BEAST SETUP  🎬                           ║
║             Ubuntu 24.04.4 LTS  ·  Noble Numbat                             ║
║   Full Hardware Auto-Detection · Focusrite Support · Pro Audio/Gaming        ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

section() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${WHITE}  ▶  $1${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "=== SECTION: $1 ==="
}

info()    { echo -e "  ${CYAN}ℹ${NC}  $*"; log "INFO: $*"; }
ok()      { echo -e "  ${LGREEN}✔${NC}  $*"; log "OK: $*"; }
warn()    { echo -e "  ${YELLOW}⚠${NC}  $*"; log "WARN: $*"; }
error()   { echo -e "  ${LRED}✘${NC}  $*" >&2; log "ERROR: $*"; }
skip()    { echo -e "  ${DIM}⊘  $*${NC}"; log "SKIP: $*"; }
step()    { echo -e "  ${MAGENTA}→${NC}  $*"; log "STEP: $*"; }

spinner_start() {
    local msg="$1"
    (
        local i=0
        while true; do
            printf "\r  ${CYAN}%s${NC}  %s " "${SPINNER_FRAMES[$((i % 8))]}" "$msg"
            sleep 0.1
            ((i++))
        done
    ) &
    SPINNER_PID=$!
}

spinner_stop() {
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" 2>/dev/null || true
        wait "$SPINNER_PID" 2>/dev/null || true
        SPINNER_PID=""
        printf "\r%-80s\r" " "
    fi
}

run_cmd() {
    local desc="$1"; shift
    spinner_start "$desc"
    if "$@" >> "$LOG_FILE" 2>&1; then
        spinner_stop
        ok "$desc"
        return 0
    else
        local exit_code=$?
        spinner_stop
        error "$desc — FAILED (exit $exit_code)."
        show_log_path
        return $exit_code
    fi
}

# ── pkg_installed: check if a .deb package is already installed ───────────────
pkg_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q '^ii'
}

# ── cmd_exists: check if a command is already on PATH ────────────────────────
cmd_exists() {
    command -v "$1" &>/dev/null
}

# ── apt_install: checks first, installs only if needed, tracks result ─────────
# Usage: apt_install "Label for summary" pkg1 pkg2 ...
# The label is what appears in the final summary — make it human-readable.
apt_install() {
    local desc="$1"; shift
    local pkgs=("$@")
    local already_all=true
    local to_install=()

    # Check each package individually
    for pkg in "${pkgs[@]}"; do
        # Strip :i386 / :amd64 suffixes for the dpkg check
        local base_pkg="${pkg%%:*}"
        if ! pkg_installed "$base_pkg"; then
            already_all=false
            to_install+=("$pkg")
        fi
    done

    # If everything is already installed — skip
    if $already_all; then
        skip "$desc — already installed"
        TRACK_SKIPPED+=("$desc")
        return 0
    fi

    # Some or all need installing
    spinner_start "Installing: $desc"
    if DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        "${pkgs[@]}" >> "$LOG_FILE" 2>&1; then
        spinner_stop
        ok "Installed: $desc"
        TRACK_INSTALLED+=("$desc")
    else
        spinner_stop
        warn "Partial/failed install: $desc"
        show_log_path
        TRACK_FAILED+=("$desc")
    fi
}

# ── flatpak_install: checks if already installed, tracks result ───────────────
# Usage: flatpak_install "Label" "com.example.App"
flatpak_install() {
    local desc="$1"
    local app_id="$2"

    if flatpak list 2>/dev/null | grep -q "$app_id"; then
        skip "$desc — already installed (Flatpak)"
        TRACK_SKIPPED+=("$desc")
        return 0
    fi

    spinner_start "Installing (Flatpak): $desc"
    if flatpak install -y flathub "$app_id" >> "$LOG_FILE" 2>&1; then
        spinner_stop
        ok "Installed (Flatpak): $desc"
        TRACK_INSTALLED+=("$desc")
    else
        spinner_stop
        warn "Flatpak install failed: $desc"
        show_log_path
        TRACK_FAILED+=("$desc")
    fi
}

# ── track_item: record non-apt/flatpak items into tracking arrays ─────────────
# Usage: track_item "installed|skipped|failed|declined" "Label"
track_item() {
    local status="$1"
    local label="$2"
    case "$status" in
        installed) TRACK_INSTALLED+=("$label") ;;
        skipped)   TRACK_SKIPPED+=("$label")   ;;
        failed)    TRACK_FAILED+=("$label")    ;;
        declined)  TRACK_DECLINED+=("$label")  ;;
    esac
}

confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local answer
    if [[ "$default" == "y" ]]; then
        read -rp "$(echo -e "  ${YELLOW}?${NC}  $prompt [Y/n]: ")" answer
        answer="${answer:-y}"
    else
        read -rp "$(echo -e "  ${YELLOW}?${NC}  $prompt [y/N]: ")" answer
        answer="${answer:-n}"
    fi
    [[ "$answer" =~ ^[Yy]$ ]]
}

pause() { read -rp "$(echo -e "\n  ${DIM}Press [Enter] to continue...${NC}")"; }

# ── Trap for clean exit ───────────────────────────────────────────────────────
cleanup() {
    spinner_stop
    echo ""
    if [[ ${1:-0} -ne 0 ]]; then
        error "Script exited unexpectedly (exit code: ${1:-?})"
        echo ""
        echo -e "  ${BOLD}${YELLOW}Diagnosis steps:${NC}"
        echo -e "  1. Check the full log for the exact error:"
        echo -e "     ${CYAN}sudo cat ${LOG_FILE}${NC}"
        echo -e "  2. Check the last 30 lines:"
        echo -e "     ${CYAN}sudo tail -30 ${LOG_FILE}${NC}"
        echo -e "  3. Re-run the script — completed steps will be skipped automatically"
        echo ""
        show_log_path
    fi
}
trap 'cleanup $?' EXIT

# ==============================================================================
# PRE-FLIGHT CHECKS
# ==============================================================================

preflight_checks() {
    section "Pre-Flight Checks"

    # ── Root check ────────────────────────────────────────────────────────────
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root."
        echo -e "  ${YELLOW}Run:${NC}  sudo bash $0"
        exit 1
    fi
    ok "Running as root"

    # ── OS check ──────────────────────────────────────────────────────────────
    if [[ ! -f /etc/os-release ]]; then
        error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        warn "This script targets Ubuntu. Detected: $PRETTY_NAME"
        confirm "Continue anyway?" n || exit 0
    else
        if [[ "$VERSION_ID" != "24.04" ]]; then
            warn "Designed for Ubuntu 24.04 — detected $VERSION_ID. Some things may differ."
            confirm "Continue anyway?" || exit 0
        else
            ok "OS: $PRETTY_NAME"
        fi
    fi

    # ── Internet check ────────────────────────────────────────────────────────
    step "Checking internet connectivity..."
    if ! ping -c 1 -W 5 8.8.8.8 &>/dev/null && ! ping -c 1 -W 5 1.1.1.1 &>/dev/null; then
        error "No internet connection detected."
        echo -e "  ${YELLOW}Please connect to the internet before running this script.${NC}"
        exit 1
    fi
    ok "Internet: Connected"

    # ── Disk space check (need at least 10 GB) ────────────────────────────────
    local free_gb
    free_gb=$(df / --output=avail -BG | tail -1 | tr -d 'G ')
    if [[ $free_gb -lt 10 ]]; then
        error "Less than 10 GB free disk space ($free_gb GB). Please free up space."
        exit 1
    fi
    ok "Disk space: ${free_gb} GB free"

    # ── Init log ──────────────────────────────────────────────────────────────
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "============================================================" >> "$LOG_FILE"
    echo " Gaming & Media Beast Setup — Started: $SCRIPT_START" >> "$LOG_FILE"
    echo " OS: $PRETTY_NAME | Kernel: $(uname -r)" >> "$LOG_FILE"
    echo "============================================================" >> "$LOG_FILE"
    ok "Log file: $LOG_FILE"
}

# ==============================================================================
# STEP 1 — SYSTEM UPDATE & UPGRADE (runs before everything else)
# ==============================================================================

system_update_upgrade() {
    section "System Update & Full Upgrade"

    info "Updating package index and upgrading all packages FIRST."
    info "This ensures every subsequent install works against current libraries."
    info "This is mandatory — skipping it risks broken dependencies."
    echo ""

    # ── Repos: universe, multiverse, restricted needed before upgrade ──────────
    step "Enabling universe / multiverse / restricted repositories..."
    run_cmd "Enable universe"    add-apt-repository universe   -y
    run_cmd "Enable multiverse"  add-apt-repository multiverse -y
    run_cmd "Enable restricted"  add-apt-repository restricted  -y

    # ── Refresh package index ─────────────────────────────────────────────────
    step "Refreshing package index..."
    run_cmd "apt-get update" apt-get update

    # ── Full upgrade ──────────────────────────────────────────────────────────
    step "Running full system upgrade (dist-upgrade)..."
    info "This may take several minutes on a freshly installed system."
    run_cmd "Full dist-upgrade" bash -c "
        DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y \
            -o Dpkg::Options::='--force-confdef' \
            -o Dpkg::Options::='--force-confold'
    "

    # ── Autoremove stale packages left by the upgrade ─────────────────────────
    step "Removing obsolete packages..."
    run_cmd "apt-get autoremove" bash -c "
        DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
    "

    # ── Refresh index again after upgrade (new packages may have been added) ──
    run_cmd "apt-get update (post-upgrade)" apt-get update

    ok "System is fully up to date — safe to proceed with installs"
}

# ==============================================================================
# STEP 2 — TIMESHIFT SNAPSHOT (runs after upgrade, before any driver changes)
# ==============================================================================

timeshift_snapshot() {
    section "Timeshift Backup Snapshot"

    info "Taking a Timeshift snapshot NOW — after the system upgrade,"
    info "before any drivers or packages are installed."
    info "If anything goes wrong you can restore to this clean state."
    echo ""

    # ── Install Timeshift if not present ──────────────────────────────────────
    if ! command -v timeshift &>/dev/null; then
        step "Installing Timeshift..."
        apt_install "Timeshift" timeshift || {
            warn "Timeshift could not be installed — skipping snapshot."
            warn "We strongly recommend installing it manually: sudo apt install timeshift"
            return 0
        }
    else
        ok "Timeshift already installed"
    fi

    # ── Detect snapshot device ────────────────────────────────────────────────
    local SNAP_DEVICE
    SNAP_DEVICE=$(df / --output=source | tail -1 || true)

    if [[ -z "$SNAP_DEVICE" ]]; then
        warn "Could not detect root device — skipping automatic snapshot."
        warn "Run manually: sudo timeshift --create --comments 'Pre-beast-setup'"
        return 0
    fi

    # ── Check free space (snapshots need at least 2 GB) ──────────────────────
    local free_gb
    free_gb=$(df / --output=avail -BG | tail -1 | tr -d 'G ')
    if [[ $free_gb -lt 5 ]]; then
        warn "Less than 5 GB free — skipping snapshot to preserve disk space."
        warn "Free up space and run: sudo timeshift --create --comments 'Pre-beast-setup'"
        return 0
    fi

    # ── Create snapshot ───────────────────────────────────────────────────────
    step "Creating Timeshift snapshot (this may take 2–5 minutes)..."
    if timeshift --create \
        --comments "Pre-beast-setup $(date '+%Y-%m-%d %H:%M')" \
        --tags D >> "$LOG_FILE" 2>&1; then
        ok "Timeshift snapshot created — system is safe to modify"
    else
        warn "Timeshift snapshot failed — check $LOG_FILE"
        warn "You can create one manually before continuing:"
        warn "  sudo timeshift --create --comments 'Pre-beast-setup'"
        if ! confirm "Continue WITHOUT a snapshot? (not recommended)"; then
            error "Aborted by user — please create a Timeshift snapshot and re-run."
            exit 1
        fi
    fi
}

# ==============================================================================
# STEP 3 — SECURE BOOT CHECK (runs before any kernel modules / drivers)
# ==============================================================================

check_secure_boot() {
    section "Secure Boot Check"

    # ── Detect Secure Boot state ──────────────────────────────────────────────
    local sb_state="unknown"
    if command -v mokutil &>/dev/null; then
        sb_state=$(mokutil --sb-state 2>/dev/null | grep -i "secure boot" | head -1 || echo "unknown")
    elif [[ -d /sys/firmware/efi ]]; then
        sb_state="EFI system detected — mokutil not available to confirm"
    else
        sb_state="Legacy BIOS — Secure Boot not applicable"
    fi

    info "Secure Boot status: ${sb_state}"

    # ── BIOS/Legacy — no action needed ───────────────────────────────────────
    if echo "$sb_state" | grep -qi "legacy\|bios\|not applicable"; then
        ok "Legacy BIOS system — Secure Boot not active, no action needed"
        return 0
    fi

    # ── Secure Boot DISABLED — no action needed ───────────────────────────────
    if echo "$sb_state" | grep -qi "disabled\|SecureBoot disabled"; then
        ok "Secure Boot is disabled — driver installation will proceed normally"
        return 0
    fi

    # ── Secure Boot ENABLED — this is the dangerous case for NVIDIA ──────────
    if echo "$sb_state" | grep -qi "enabled\|SecureBoot enabled"; then
        echo ""
        echo -e "  ${BOLD}${YELLOW}╔══════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "  ${BOLD}${YELLOW}║  ⚠  SECURE BOOT IS ENABLED — IMPORTANT NOTICE  ⚠               ║${NC}"
        echo -e "  ${BOLD}${YELLOW}╠══════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "  ${YELLOW}║${NC}                                                                  ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  Secure Boot blocks unsigned kernel modules, including the       ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  NVIDIA and Broadcom WiFi drivers this script will install.      ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}                                                                  ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  ${BOLD}WHAT WILL HAPPEN:${NC}                                             ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  After the NVIDIA driver installs, Ubuntu will display a         ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  ${BOLD}blue MOK (Machine Owner Key) screen${NC} on next reboot.           ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}                                                                  ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  ${BOLD}YOU MUST:${NC}                                                     ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  1. At the blue screen — choose 'Enroll MOK'                    ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  2. Choose 'Continue'                                           ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  3. Enter the password: ${BOLD}beast-setup${NC}                           ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  4. Choose 'Reboot'                                             ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}                                                                  ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  ${BOLD}If you skip or miss this screen:${NC}                             ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  • NVIDIA driver will NOT load → black screen / fallback         ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  • Fix: sudo mokutil --import /var/lib/shim-signed/mok/MOK.der   ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}                                                                  ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  ${BOLD}Alternative:${NC} Disable Secure Boot in BIOS/UEFI first,         ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}  then re-run this script. Simpler for home gaming systems.       ${YELLOW}║${NC}"
        echo -e "  ${YELLOW}║${NC}                                                                  ${YELLOW}║${NC}"
        echo -e "  ${BOLD}${YELLOW}╚══════════════════════════════════════════════════════════════════╝${NC}"
        echo ""

        # ── Pre-enroll a MOK key so the NVIDIA DKMS signs its module ──────────
        if [[ "$GPU_VENDOR" == "nvidia" ]]; then
            step "Pre-generating MOK key for NVIDIA driver signing..."
            if apt_install "MOK signing tools" mokutil sbsign openssl 2>/dev/null; then
                local MOK_DIR="/var/lib/shim-signed/mok"
                mkdir -p "$MOK_DIR"
                if [[ ! -f "$MOK_DIR/MOK.key" ]]; then
                    run_cmd "Generate MOK key pair" bash -c "
                        openssl req -new -x509 -newkey rsa:2048 \
                            -keyout '$MOK_DIR/MOK.key' \
                            -out '$MOK_DIR/MOK.der' \
                            -days 3650 -subj '/CN=Beast-Setup-MOK/' \
                            -nodes -outform DER >> '$LOG_FILE' 2>&1
                        chmod 600 '$MOK_DIR/MOK.key'
                    " || warn "MOK key generation failed — you may need to enroll manually"
                else
                    skip "MOK key already exists"
                fi

                if [[ -f "$MOK_DIR/MOK.der" ]]; then
                    run_cmd "Enqueue MOK for UEFI enrollment" bash -c "
                        echo 'beast-setup' | mokutil --import '$MOK_DIR/MOK.der' \
                            --root-pw 2>/dev/null || \
                        mokutil --import '$MOK_DIR/MOK.der' << 'MOKEOF'
beast-setup
beast-setup
MOKEOF
                    " >> "$LOG_FILE" 2>&1 || \
                    warn "MOK enqueue failed — you may need to enroll the key manually at next reboot"
                    ok "MOK key queued — enter password 'beast-setup' at the blue MOK screen after reboot"
                fi
            fi
        fi

        confirm "I understand the MOK requirement — continue with installation?" || {
            info "You can disable Secure Boot in BIOS/UEFI and re-run this script."
            exit 0
        }

    else
        # Unknown state — warn but don't block
        warn "Could not definitively determine Secure Boot state: $sb_state"
        warn "If you have NVIDIA hardware, be prepared for a MOK enrollment prompt on reboot."
    fi
}

# ==============================================================================
# HARDWARE DETECTION
# ==============================================================================

# Globals set by detect_*
GPU_VENDOR=""        # nvidia | amd | intel | unknown
GPU_MODEL=""
CPU_VENDOR=""        # intel | amd | unknown
CPU_MODEL=""
HAS_FOCUSRITE=false
FOCUSRITE_MODEL=""
AUDIO_CHIPSET=""
NET_VENDOR=""
HAS_BLUETOOTH=false
RAM_GB=0
IS_LAPTOP=false
KERNEL_VER=""

detect_cpu() {
    section "CPU Detection"
    CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo "Unknown")
    KERNEL_VER=$(uname -r)

    if echo "$CPU_MODEL" | grep -qi "intel"; then
        CPU_VENDOR="intel"
        ok "CPU: Intel — $CPU_MODEL"
    elif echo "$CPU_MODEL" | grep -qi "amd"; then
        CPU_VENDOR="amd"
        ok "CPU: AMD — $CPU_MODEL"
    else
        CPU_VENDOR="unknown"
        warn "CPU vendor unknown: $CPU_MODEL"
    fi

    # RAM
    RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    RAM_GB=$(( RAM_KB / 1024 / 1024 ))
    ok "RAM: ${RAM_GB} GB"

    # Laptop detection
    if [[ -d /sys/class/power_supply/BAT0 ]] || [[ -d /sys/class/power_supply/BAT1 ]]; then
        IS_LAPTOP=true
        info "System type: Laptop"
    else
        info "System type: Desktop"
    fi
}

detect_gpu() {
    section "GPU Detection"

    if ! command -v lspci &>/dev/null; then
        run_cmd "Installing pciutils" apt-get install -y pciutils
    fi

    local pci_gpu
    pci_gpu=$(lspci 2>/dev/null | grep -iE 'VGA|3D|Display' || true)

    if [[ -z "$pci_gpu" ]]; then
        warn "No GPU detected via lspci"
        GPU_VENDOR="unknown"
        return
    fi

    info "Detected PCI GPU(s):"
    echo "$pci_gpu" | while read -r line; do
        echo -e "    ${DIM}$line${NC}"
    done

    if echo "$pci_gpu" | grep -qi "nvidia"; then
        GPU_VENDOR="nvidia"
        GPU_MODEL=$(echo "$pci_gpu" | grep -i nvidia | head -1 | sed 's/.*: //')
        ok "GPU Vendor: NVIDIA — $GPU_MODEL"
    elif echo "$pci_gpu" | grep -qi "amd\|ati\|radeon"; then
        GPU_VENDOR="amd"
        GPU_MODEL=$(echo "$pci_gpu" | grep -iE 'amd|ati|radeon' | head -1 | sed 's/.*: //')
        ok "GPU Vendor: AMD — $GPU_MODEL"
    elif echo "$pci_gpu" | grep -qi "intel"; then
        GPU_VENDOR="intel"
        GPU_MODEL=$(echo "$pci_gpu" | grep -i intel | head -1 | sed 's/.*: //')
        ok "GPU Vendor: Intel — $GPU_MODEL"
    else
        GPU_VENDOR="unknown"
        warn "GPU vendor not recognised. Manual driver install may be needed."
    fi
}

detect_audio() {
    section "Audio Hardware Detection"

    if ! command -v lsusb &>/dev/null; then
        run_cmd "Installing usbutils" apt-get install -y usbutils
    fi

    # ── Focusrite USB detection ───────────────────────────────────────────────
    # Focusrite Vendor ID: 1235
    local usb_audio
    usb_audio=$(lsusb 2>/dev/null || true)

    if echo "$usb_audio" | grep -qi "1235:"; then
        HAS_FOCUSRITE=true
        FOCUSRITE_MODEL=$(echo "$usb_audio" | grep -i "1235:" | head -1 | sed 's/.*ID [0-9a-f:]*  *//')
        ok "Focusrite device detected: ${FOCUSRITE_MODEL}"
    else
        # Also check PCI audio
        local pci_audio
        pci_audio=$(lspci 2>/dev/null | grep -i audio || true)
        if echo "$pci_audio" | grep -qi "focusrite"; then
            HAS_FOCUSRITE=true
            FOCUSRITE_MODEL=$(echo "$pci_audio" | grep -i focusrite | head -1 | sed 's/.*: //')
            ok "Focusrite device detected (PCI): ${FOCUSRITE_MODEL}"
        else
            info "No Focusrite device currently connected."
            info "alsa-scarlett-gui will still be installed for future use."
        fi
    fi

    # ── General audio chipset ─────────────────────────────────────────────────
    AUDIO_CHIPSET=$(lspci 2>/dev/null | grep -iE 'audio|sound' | head -1 | sed 's/.*: //' || echo "Unknown")
    ok "Onboard audio: $AUDIO_CHIPSET"

    # ── Bluetooth ─────────────────────────────────────────────────────────────
    if lsusb 2>/dev/null | grep -qi "bluetooth" || \
       lspci 2>/dev/null | grep -qi "bluetooth"; then
        HAS_BLUETOOTH=true
        ok "Bluetooth hardware detected"
    else
        info "No Bluetooth hardware detected"
    fi
}

detect_network() {
    section "Network Hardware Detection"
    local net_info
    net_info=$(lspci 2>/dev/null | grep -iE 'network|ethernet|wireless|wifi' || true)
    if [[ -n "$net_info" ]]; then
        NET_VENDOR=$(echo "$net_info" | head -1 | sed 's/.*: //')
        ok "Network: $NET_VENDOR"
        echo "$net_info" | while read -r line; do
            echo -e "    ${DIM}$line${NC}"
        done
    else
        info "No additional network hardware detected via lspci"
    fi
}

print_hw_summary() {
    section "Hardware Summary"
    echo ""
    echo -e "  ${BOLD}${WHITE}┌─────────────────────────────────────────────┐${NC}"
    echo -e "  ${BOLD}${WHITE}│           DETECTED HARDWARE                 │${NC}"
    echo -e "  ${BOLD}${WHITE}├─────────────────────────────────────────────┤${NC}"
    echo -e "  ${WHITE}│${NC}  CPU    : ${CYAN}$CPU_MODEL${NC}"
    echo -e "  ${WHITE}│${NC}  RAM    : ${CYAN}${RAM_GB} GB${NC}"
    echo -e "  ${WHITE}│${NC}  GPU    : ${CYAN}$GPU_MODEL${NC} (${GPU_VENDOR})"
    echo -e "  ${WHITE}│${NC}  Audio  : ${CYAN}$AUDIO_CHIPSET${NC}"
    if $HAS_FOCUSRITE; then
    echo -e "  ${WHITE}│${NC}  Scarlett: ${GREEN}$FOCUSRITE_MODEL${NC}"
    fi
    echo -e "  ${WHITE}│${NC}  Network: ${CYAN}$NET_VENDOR${NC}"
    echo -e "  ${WHITE}│${NC}  BT     : $(${HAS_BLUETOOTH} && echo "${GREEN}Yes${NC}" || echo "${DIM}No${NC}")"
    echo -e "  ${WHITE}│${NC}  Laptop : $(${IS_LAPTOP} && echo "${CYAN}Yes${NC}" || echo "${DIM}No${NC}")"
    echo -e "  ${BOLD}${WHITE}└─────────────────────────────────────────────┘${NC}"
    echo ""

    confirm "Does this look correct? Proceed with installation?" || {
        warn "User aborted at hardware summary."
        exit 0
    }
}

# ==============================================================================
# SYSTEM PREPARATION
# ==============================================================================

prepare_system() {
    section "System Preparation"

    # NOTE: apt-get update and dist-upgrade have already been run by
    # system_update_upgrade() at the very start. We only install tools here.

    step "Installing essential build tools..."
    apt_install "Build essentials" \
        build-essential cmake git curl wget \
        software-properties-common apt-transport-https \
        gnupg lsb-release ca-certificates \
        pciutils usbutils lshw dmidecode \
        dkms linux-headers-"$(uname -r)" \
        python3 python3-pip python3-venv \
        flatpak gdebi-core unzip p7zip-full

    step "Adding Flatpak / Flathub..."
    if ! command -v flatpak &>/dev/null || ! flatpak remote-list 2>/dev/null | grep -q flathub; then
        run_cmd "Add Flathub remote" bash -c "
            apt-get install -y flatpak gnome-software-plugin-flatpak 2>/dev/null || true
            flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
        "
    else
        skip "Flathub already configured"
    fi
}

# ==============================================================================
# GPU DRIVER INSTALLATION
# ==============================================================================

install_nvidia_drivers() {
    section "NVIDIA Driver Installation"

    # Ensure ubuntu-drivers-common is installed before calling ubuntu-drivers
    apt_install "ubuntu-drivers-common" ubuntu-drivers-common 2>/dev/null || true

    # Detect best driver version
    step "Detecting recommended NVIDIA driver..."
    local recommended
    if command -v ubuntu-drivers &>/dev/null; then
        recommended=$(ubuntu-drivers devices 2>/dev/null | grep 'recommended' | awk '{print $3}' | head -1 || true)
    fi

    if [[ -z "$recommended" ]]; then
        recommended="nvidia-driver-550"
        warn "Could not auto-detect — defaulting to $recommended"
    else
        ok "Recommended driver: $recommended"
    fi

    # Extract the numeric version safely — handles nvidia-driver-550 AND nvidia-driver-550-open
    local nvidia_ver
    nvidia_ver=$(echo "$recommended" | grep -oP '\d+' | head -1)
    if [[ -z "$nvidia_ver" ]]; then
        nvidia_ver="550"
        warn "Could not extract NVIDIA version number — defaulting to $nvidia_ver"
    fi

    # Add graphics-drivers PPA for latest stable
    step "Adding graphics-drivers PPA..."
    run_cmd "Add nvidia PPA" bash -c "
        add-apt-repository ppa:graphics-drivers/ppa -y
        apt-get update -qq
    "

    apt_install "NVIDIA Driver + Vulkan tools" \
        "$recommended" \
        "nvidia-utils-${nvidia_ver}" \
        libvulkan1 libvulkan-dev \
        vulkan-tools mesa-vulkan-drivers \
        nvidia-settings

    # CUDA toolkit is optional — it's ~1.5 GB and only needed for GPU compute,
    # AI/ML, or video encoding workflows. Most gamers do not need it.
    if confirm "Install NVIDIA CUDA Toolkit (~1.5 GB — for AI/ML/GPU compute only)?" n; then
        apt_install "NVIDIA CUDA Toolkit" nvidia-cuda-toolkit
    else
        track_item "declined" "NVIDIA CUDA Toolkit"
        info "Skipped CUDA toolkit — install later with: sudo apt install nvidia-cuda-toolkit"
    fi

    # PRIME support for laptops with hybrid graphics
    if $IS_LAPTOP; then
        # switcheroo-control is the correct Ubuntu 24.04 way to manage hybrid GPUs
        # prime-indicator is an old PPA package not available in Ubuntu 24.04 repos
        apt_install "NVIDIA PRIME + switcheroo (laptop hybrid graphics)" \
            nvidia-prime \
            switcheroo-control 2>/dev/null || true
        run_cmd "Enable switcheroo-control" bash -c "
            systemctl enable --now switcheroo-control 2>/dev/null || true
        "
        ok "PRIME + switcheroo-control configured for hybrid GPU laptop"
    fi

    # 32-bit libs for Steam/Wine compatibility
    step "Enabling 32-bit architecture for NVIDIA/Steam..."
    run_cmd "Enable i386" dpkg --add-architecture i386
    run_cmd "apt-get update" apt-get update
    apt_install "32-bit NVIDIA libs" \
        libvulkan1:i386 \
        libgl1:i386 2>/dev/null || true

    ok "NVIDIA drivers installed. A reboot is required to activate them."
}

install_amd_drivers() {
    section "AMD GPU Driver Installation"

    # Mesa + AMDGPU PRO for Vulkan/OpenGL
    step "Adding oibaf PPA (latest Mesa)..."
    run_cmd "Add Mesa PPA" bash -c "
        add-apt-repository ppa:oibaf/graphics-drivers -y
        apt-get update -qq
    " || warn "oibaf PPA failed — using default Mesa"

    apt_install "Mesa + AMDGPU drivers" \
        mesa-vulkan-drivers \
        mesa-va-drivers \
        mesa-vdpau-drivers \
        libvulkan1 vulkan-tools \
        libdrm-amdgpu1 \
        xserver-xorg-video-amdgpu \
        radeontop \
        libgl1-mesa-dri

    # 32-bit
    run_cmd "Enable i386" dpkg --add-architecture i386
    run_cmd "apt-get update" apt-get update
    apt_install "32-bit Mesa libs" \
        libvulkan1:i386 \
        mesa-vulkan-drivers:i386 \
        libgl1-mesa-dri:i386 2>/dev/null || true

    # ROCm for AMD compute (optional — skip on low-RAM systems)
    if [[ $RAM_GB -ge 8 ]]; then
        if confirm "Install ROCm (AMD GPU compute — useful for AI/ML workflows)?" n; then
            step "Adding ROCm repository..."
            run_cmd "Add ROCm repo" bash -c "
                wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key 2>/dev/null | \
                    gpg --dearmor -o /etc/apt/keyrings/rocm.gpg 2>/dev/null || true
                echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/6.0 noble main' \
                    > /etc/apt/sources.list.d/rocm.list 2>/dev/null || true
                apt-get update -qq 2>/dev/null || true
            " || warn "ROCm repo setup failed — skipping ROCm"
            apt_install "ROCm" rocm-hip-runtime 2>/dev/null || warn "ROCm install failed — skipping"
        fi
    fi

    ok "AMD GPU drivers installed."
}

install_intel_drivers() {
    section "Intel GPU Driver Installation"

    apt_install "Intel GPU drivers + media" \
        intel-media-va-driver-non-free \
        i965-va-driver \
        intel-gpu-tools \
        mesa-vulkan-drivers \
        libvulkan1 vulkan-tools \
        libva-drm2 libva-x11-2 vainfo \
        libdrm-intel1

    # Intel compute runtime (for ARC / Xe GPUs)
    if lspci 2>/dev/null | grep -qi "intel.*arc\|intel.*xe"; then
        step "Intel ARC/Xe detected — installing compute runtime..."
        apt_install "Intel compute runtime" intel-opencl-icd intel-level-zero-gpu || true
    fi

    ok "Intel GPU drivers installed."
}

install_gpu_drivers() {
    case "$GPU_VENDOR" in
        nvidia) install_nvidia_drivers ;;
        amd)    install_amd_drivers    ;;
        intel)  install_intel_drivers  ;;
        *)
            warn "Unknown GPU vendor — installing generic Vulkan + Mesa fallback"
            apt_install "Generic GPU/Vulkan" \
                mesa-vulkan-drivers libvulkan1 vulkan-tools mesa-utils
            ;;
    esac

    # Vulkan validation layers (useful for gaming)
    apt_install "Vulkan validation layers" vulkan-validationlayers || true
}

# ==============================================================================
# NETWORK DRIVERS
# ==============================================================================

install_network_drivers() {
    section "Network Driver Support"

    apt_install "Linux firmware (covers most devices)" \
        linux-firmware 2>/dev/null || true

    # Realtek WiFi/Ethernet — covered by linux-firmware on Ubuntu;
    # extra tool for older cards that need separate firmware loader
    if lspci 2>/dev/null | grep -qi "realtek" || lsusb 2>/dev/null | grep -qi "realtek"; then
        apt_install "Realtek extra tools" r8168-dkms 2>/dev/null || true
        ok "Realtek extra drivers attempted"
    fi

    # Intel WiFi — covered by linux-firmware; no separate package needed on Ubuntu
    if lspci 2>/dev/null | grep -qi "intel.*wireless\|intel.*wi-fi\|intel.*wifi"; then
        ok "Intel WiFi firmware: bundled in linux-firmware"
    fi

    # Broadcom WiFi — bcmwl IS a separate package on Ubuntu (multiverse)
    if lspci 2>/dev/null | grep -qi "broadcom"; then
        apt_install "Broadcom WiFi drivers" \
            firmware-b43-installer \
            bcmwl-kernel-source 2>/dev/null || true
        ok "Broadcom drivers installed"
    fi

    # Atheros/Qualcomm — covered by linux-firmware on Ubuntu
    if lspci 2>/dev/null | grep -qi "atheros\|qualcomm\|qca"; then
        ok "Atheros/Qualcomm firmware: bundled in linux-firmware"
    fi

    # Bluetooth stack
    # NOTE: pulseaudio-module-bluetooth is intentionally EXCLUDED here —
    # we use PipeWire (libspa-0.2-bluetooth is installed in the audio section).
    # Installing the PA module would pull PulseAudio back in and break audio.
    if $HAS_BLUETOOTH; then
        apt_install "Bluetooth stack" \
            bluez bluez-tools \
            blueman 2>/dev/null || true
        run_cmd "Enable Bluetooth service" systemctl enable bluetooth || true
        ok "Bluetooth stack installed"
    fi
}

# ==============================================================================
# AUDIO STACK — PipeWire + ALSA + JACK
# ==============================================================================

install_audio_stack() {
    section "Pro Audio Stack (PipeWire + ALSA + JACK)"

    # Remove PulseAudio if present (PipeWire replaces it)
    if pkg_installed pulseaudio; then
        step "Removing PulseAudio (replacing with PipeWire)..."
        run_cmd "Remove PulseAudio" bash -c "
            apt-get remove -y pulseaudio pulseaudio-utils 2>/dev/null || true
        "
    fi

    apt_install "PipeWire core" \
        pipewire pipewire-audio \
        pipewire-alsa pipewire-pulse \
        pipewire-jack pipewire-v4l2 \
        wireplumber \
        libspa-0.2-bluetooth \
        libspa-0.2-jack \
        libpipewire-0.3-0

    apt_install "ALSA tools" \
        alsa-base alsa-utils alsa-tools \
        alsamixergui \
        alsa-oss libasound2-plugins

    apt_install "JACK audio" \
        jackd2 qjackctl \
        jack-tools jack-capture

    apt_install "Audio utilities" \
        pavucontrol \
        helvum                \
        qpwgraph              \
        easyeffects           \
        carla carla-data       \
        lsp-plugins-lv2       \
        calf-plugins          \
        audacity              \
        ardour

    # Enable PipeWire for current (root) session — user session handled via udev
    step "Activating PipeWire services..."
    run_cmd "Enable PipeWire systemd service" bash -c "
        systemctl --global enable pipewire.socket 2>/dev/null || true
        systemctl --global enable pipewire-pulse.socket 2>/dev/null || true
        systemctl --global enable wireplumber 2>/dev/null || true
    "

    # RT privileges for audio (real-time scheduling)
    step "Configuring real-time audio privileges..."
    if ! grep -q '@audio' /etc/security/limits.d/audio.conf 2>/dev/null; then
        cat > /etc/security/limits.d/audio.conf << 'EOF'
# Real-time audio privileges
@audio   -  rtprio     95
@audio   -  memlock    unlimited
@audio   -  nice       -19
EOF
        ok "RT audio limits configured"
    else
        skip "RT audio limits already set"
    fi

    # Add calling user (the one who invoked sudo) to audio group
    local REAL_USER="${SUDO_USER:-}"
    if [[ -n "$REAL_USER" ]]; then
        run_cmd "Add $REAL_USER to audio/video groups" bash -c "
            usermod -aG audio,video,realtime '$REAL_USER' 2>/dev/null || \
            usermod -aG audio,video '$REAL_USER'
        "
    fi

    ok "Pro audio stack installed"
}

# ==============================================================================
# FOCUSRITE / ALSA-SCARLETT-GUI
# ==============================================================================

install_focusrite() {
    section "Focusrite Scarlett Support & alsa-scarlett-gui"

    info "The alsa-scarlett-gui provides a full mixer/control interface"
    info "for all Focusrite Scarlett, Clarett USB, and Vocaster USB interfaces."

    # ── Kernel module check ───────────────────────────────────────────────────
    step "Checking snd-usb-audio / scarlett kernel module..."
    local kernel_ver
    kernel_ver=$(uname -r)

    # snd-usb-audio is built into mainline; scarlett2 protocol added in 5.14+
    local kern_maj kern_min
    kern_maj=$(echo "$kernel_ver" | cut -d. -f1)
    kern_min=$(echo "$kernel_ver" | cut -d. -f2)

    if [[ $kern_maj -gt 5 ]] || { [[ $kern_maj -eq 5 ]] && [[ $kern_min -ge 14 ]]; }; then
        ok "Kernel $kernel_ver has full Scarlett2 protocol support (snd-usb-audio)"
    else
        warn "Kernel $kernel_ver may need upgrade for full Scarlett support."
        warn "Ubuntu 24.04 ships kernel 6.8+ so this should not be an issue."
    fi

    # ── Install dependencies ──────────────────────────────────────────────────
    # libssl-dev is required — scarlett2-firmware.c includes openssl/sha.h
    # Without it the build fails with: fatal error: openssl/sha.h: No such file
    apt_install "alsa-scarlett-gui build dependencies" \
        alsa-utils alsa-tools \
        libgtk-4-dev libgtk-4-1 \
        libgirepository1.0-dev \
        build-essential git cmake \
        libasound2-dev \
        libssl-dev \
        pkg-config meson ninja-build

    # ── Build & install alsa-scarlett-gui ─────────────────────────────────────
    local BUILD_DIR="/opt/alsa-scarlett-gui-build"
    local INSTALL_BIN="/usr/local/bin/alsa-scarlett-gui"

    if [[ -f "$INSTALL_BIN" ]]; then
        if confirm "alsa-scarlett-gui already installed. Re-install/update?"; then
            rm -rf "$BUILD_DIR"
        else
            skip "alsa-scarlett-gui — kept existing install"
            track_item "skipped" "alsa-scarlett-gui (Focusrite mixer)"
            return 0
        fi
    fi

    step "Cloning alsa-scarlett-gui from GitHub..."
    run_cmd "Clone alsa-scarlett-gui" bash -c "
        rm -rf '$BUILD_DIR'
        git clone https://github.com/geoffreybennett/alsa-scarlett-gui.git '$BUILD_DIR' --depth=1
    "

    step "Building alsa-scarlett-gui..."
    local scarlett_installed=false

    # Primary build: Makefile in the src/ subdirectory
    run_cmd "Build alsa-scarlett-gui" bash -c "
        cd '$BUILD_DIR/src'
        make -j\$(nproc)
    " && scarlett_installed=true || {
        # Secondary fallback: meson — must be run from the src/ dir where meson.build lives
        warn "Makefile build failed — trying meson build..."
        run_cmd "Meson build alsa-scarlett-gui" bash -c "
            cd '$BUILD_DIR/src'
            meson setup ../build-meson --prefix=/usr/local
            ninja -C ../build-meson
            ninja -C ../build-meson install
        " && scarlett_installed=true || {
            # The app is NOT on Flathub — manual install is the only remaining option
            warn "Both build methods failed."
            warn "To install manually, run these commands:"
            warn "  sudo apt install libssl-dev libgtk-4-dev libasound2-dev"
            warn "  git clone https://github.com/geoffreybennett/alsa-scarlett-gui"
            warn "  cd alsa-scarlett-gui/src && make -j\$(nproc)"
            warn "  sudo install -m755 alsa-scarlett-gui /usr/local/bin/"
            track_item "failed" "alsa-scarlett-gui (Focusrite mixer)"
            return 0
        }
    }

    step "Installing alsa-scarlett-gui binary..."
    run_cmd "Install alsa-scarlett-gui" bash -c "
        # Binary lives in src/ after a make build
        if [[ -f '$BUILD_DIR/src/alsa-scarlett-gui' ]]; then
            install -m 755 '$BUILD_DIR/src/alsa-scarlett-gui' /usr/local/bin/
        # Or in build-meson/ after a meson build
        elif [[ -f '$BUILD_DIR/build-meson/src/alsa-scarlett-gui' ]]; then
            install -m 755 '$BUILD_DIR/build-meson/src/alsa-scarlett-gui' /usr/local/bin/
        else
            echo 'Binary not found in expected locations' >&2
            exit 1
        fi
        # Desktop entry — lives in aps/ directory in the repo
        if [[ -f '$BUILD_DIR/aps/alsa-scarlett-gui.desktop' ]]; then
            install -m 644 '$BUILD_DIR/aps/alsa-scarlett-gui.desktop' /usr/share/applications/ 2>/dev/null || true
        fi
        # Icon
        if [[ -f '$BUILD_DIR/aps/alsa-scarlett-gui.png' ]]; then
            install -m 644 '$BUILD_DIR/aps/alsa-scarlett-gui.png' /usr/share/pixmaps/ 2>/dev/null || true
        fi
    " || warn "Binary copy step had issues — check $LOG_FILE"

    # Track result based on whether build succeeded
    if $scarlett_installed; then
        track_item "installed" "alsa-scarlett-gui (Focusrite mixer)"
    fi

    # ── udev rules for Focusrite devices ──────────────────────────────────────
    step "Installing Focusrite udev rules..."
    run_cmd "Install Focusrite udev rules" bash -c "
        if [[ -f '$BUILD_DIR/aps/51-scarlett.rules' ]]; then
            install -m 644 '$BUILD_DIR/aps/51-scarlett.rules' /etc/udev/rules.d/
        else
            # Generic Focusrite udev rule (vendor 1235)
            cat > /etc/udev/rules.d/51-focusrite-scarlett.rules << 'UDEV'
# Focusrite Scarlett / Clarett USB / Vocaster
# Allow user access without root for all Focusrite devices (VID 1235)
SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"1235\", MODE=\"0664\", GROUP=\"audio\", TAG+=\"uaccess\"
SUBSYSTEM==\"sound\", ATTRS{idVendor}==\"1235\", MODE=\"0664\", GROUP=\"audio\", TAG+=\"uaccess\"
UDEV
        fi
        udevadm control --reload-rules
        udevadm trigger
    "

    # ── Kernel module tuning for Scarlett ─────────────────────────────────────
    step "Tuning snd-usb-audio for Focusrite..."
    cat > /etc/modprobe.d/scarlett.conf << 'EOF'
# Enable Scarlett2 mixer protocol for Focusrite devices
# This unlocks the full hardware mixer in alsa-scarlett-gui
options snd-usb-audio device_setup=1
EOF
    ok "Scarlett2 protocol enabled via modprobe options"

    # ── Create desktop launcher ───────────────────────────────────────────────
    cat > /usr/share/applications/alsa-scarlett-gui.desktop << 'EOF'
[Desktop Entry]
Name=ALSA Scarlett GUI
GenericName=Focusrite Mixer
Comment=Hardware mixer for Focusrite Scarlett / Clarett / Vocaster
Exec=alsa-scarlett-gui
Icon=alsa-scarlett-gui
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Mixer;
Keywords=focusrite;scarlett;mixer;audio;interface;
EOF
    ok "Desktop launcher created"

    ok "alsa-scarlett-gui installed successfully"
    info "Launch it from your application menu or run: alsa-scarlett-gui"
    info "Plug in your Focusrite device first for the mixer to appear."
}

# ==============================================================================
# GAMING STACK
# ==============================================================================

install_gaming() {
    section "Gaming Stack"

    # ── Steam ─────────────────────────────────────────────────────────────────
    if confirm "Install Steam?"; then
        step "Adding Steam repository..."
        run_cmd "Enable i386 for Steam" dpkg --add-architecture i386
        run_cmd "apt-get update" apt-get update
        apt_install "Steam" steam-installer || \
        apt_install "Steam (fallback)" steam
    else
        track_item "declined" "Steam"
    fi

    # ── Lutris ────────────────────────────────────────────────────────────────
    if confirm "Install Lutris (game manager for Windows games)?"; then
        run_cmd "Add Lutris PPA" bash -c "
            add-apt-repository ppa:lutris-team/lutris -y
            apt-get update -qq
        "
        apt_install "Lutris" lutris
    else
        track_item "declined" "Lutris"
    fi

    # ── Heroic Games Launcher (Epic / GOG / Amazon) ───────────────────────────
    if confirm "Install Heroic Games Launcher (Epic/GOG/Amazon)?"; then
        flatpak_install "Heroic Games Launcher" com.heroicgameslauncher.hgl
    else
        track_item "declined" "Heroic Games Launcher"
    fi

    # ── Wine (basic runtime for Lutris/Steam compatibility) ──────────────────
    # NOTE: Full Windows app support (double-click .exe/.msi, all VC++ runtimes,
    # .NET, DXVK, binfmt, Bottles, 14 known fixes) is handled by the companion
    # script: windows-app-support.sh — run it after this script for Zorin-grade
    # Windows application compatibility.
    step "Installing Wine base (full stack via windows-app-support.sh)..."
    apt_install "Wine base" wine wine64 winbind 2>/dev/null || true

    # ── Proton Plus (manage Proton-GE / Wine-GE / Luxtorpeda builds) ─────────
    if confirm "Install Proton Plus (manage custom Proton/Wine builds)?"; then
        flatpak_install "Proton Plus" com.vysp3r.ProtonPlus
    else
        track_item "declined" "Proton Plus"
    fi

    # ── GameMode (Feral Interactive) ──────────────────────────────────────────
    apt_install "GameMode (CPU/GPU performance booster)" \
        gamemode libgamemode0 libgamemodeauto0

    # ── MangoHud (FPS/GPU overlay) ────────────────────────────────────────────
    apt_install "MangoHud (FPS overlay)" \
        mangohud 2>/dev/null || \
        warn "MangoHud not in repos — install manually from https://github.com/flightlessmango/MangoHud/releases"

    # ── GOverlay (MangoHud config GUI) ───────────────────────────────────────
    flatpak_install "GOverlay (MangoHud config GUI)" io.github.benjamimgois.goverlay

    # ── Vulkan tools ──────────────────────────────────────────────────────────
    apt_install "Vulkan + gaming libs" \
        vulkan-tools mesa-utils \
        libvkd3d1 libvkd3d-dev \
        libopenal1 libopenal-dev \
        libsdl2-2.0-0 libsdl2-dev \
        libsdl2-image-2.0-0 \
        libsdl2-mixer-2.0-0 \
        libogg0 libvorbis0a \
        libgnutls30

    # ── RetroArch (emulation) ─────────────────────────────────────────────────
    if confirm "Install RetroArch (multi-system emulator)?" n; then
        flatpak_install "RetroArch" org.libretro.RetroArch
    else
        track_item "declined" "RetroArch"
    fi

    # ── DXVK (Direct3D → Vulkan) ─────────────────────────────────────────────
    # NOTE: The 'dxvk' apt package was removed from Ubuntu repos in 22.10
    # and does not exist in Ubuntu 24.04. DXVK is installed properly via
    # GitHub download in windows-app-support.sh. Steam and Lutris also
    # bundle their own DXVK automatically per-game.
    info "DXVK: handled by windows-app-support.sh and Steam/Lutris automatically"
    track_item "skipped" "DXVK — managed by windows-app-support.sh"

    ok "Gaming stack installed"
}

# ==============================================================================
# MEDIA STACK
# ==============================================================================

install_media() {
    section "Media Stack"

    # ── Codecs ────────────────────────────────────────────────────────────────
    step "Installing multimedia codecs..."

    # Pre-accept the Microsoft fonts EULA silently.
    # Without this, ttf-mscorefonts-installer (pulled by ubuntu-restricted-extras)
    # shows an interactive dialog and the script hangs FOREVER waiting for input.
    step "Pre-accepting Microsoft fonts EULA..."
    if pkg_installed debconf; then
        echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" \
            | debconf-set-selections 2>/dev/null || true
        ok "Microsoft fonts EULA pre-accepted"
    fi
    apt_install "Ubuntu restricted extras + codecs" \
        ubuntu-restricted-extras \
        ubuntu-restricted-addons \
        ffmpeg \
        gstreamer1.0-plugins-base \
        gstreamer1.0-plugins-good \
        gstreamer1.0-plugins-bad \
        gstreamer1.0-plugins-ugly \
        gstreamer1.0-libav \
        gstreamer1.0-vaapi \
        gstreamer1.0-pipewire \
        libavcodec-extra \
        libdvd-pkg

    # Trigger libdvd-pkg post-install
    # libdvd-pkg shows an interactive <Yes>/<No> dialog even with
    # DEBIAN_FRONTEND=noninteractive — must pre-answer via debconf-set-selections
    step "Pre-answering libdvd-pkg dialog to prevent interactive hang..."
    echo "libdvd-pkg libdvd-pkg/build boolean true" | debconf-set-selections 2>/dev/null || true
    run_cmd "Configure libdvd-pkg" bash -c "
        DEBIAN_FRONTEND=noninteractive dpkg-reconfigure libdvd-pkg 2>/dev/null || true
    "
    track_item "installed" "libdvdcss (DVD playback)"

    # ── VLC ───────────────────────────────────────────────────────────────────
    apt_install "VLC media player" vlc vlc-plugin-access-extra

    # ── MPV ───────────────────────────────────────────────────────────────────
    apt_install "MPV player" mpv

    # ── OBS Studio ───────────────────────────────────────────────────────────
    if confirm "Install OBS Studio (streaming/recording)?"; then
        run_cmd "Add OBS PPA" bash -c "
            add-apt-repository ppa:obsproject/obs-studio -y
            apt-get update -qq
        "
        apt_install "OBS Studio" obs-studio
    else
        track_item "declined" "OBS Studio"
    fi

    # ── Kdenlive (video editor) ───────────────────────────────────────────────
    if confirm "Install Kdenlive (video editor)?" n; then
        apt_install "Kdenlive" kdenlive
    else
        track_item "declined" "Kdenlive"
    fi

    # ── Handbrake ─────────────────────────────────────────────────────────────
    if confirm "Install HandBrake (video transcoder)?" n; then
        run_cmd "Add HandBrake PPA" bash -c "
            add-apt-repository ppa:stebbins/handbrake-releases -y
            apt-get update -qq
        " || true
        apt_install "HandBrake" handbrake handbrake-cli 2>/dev/null || \
        flatpak_install "HandBrake" fr.handbrake.ghb
    else
        track_item "declined" "HandBrake"
    fi

    # ── Spotify ───────────────────────────────────────────────────────────────
    if confirm "Install Spotify?" n; then
        flatpak_install "Spotify" com.spotify.Client
    else
        track_item "declined" "Spotify"
    fi

    # ── Jellyfin Media Server ─────────────────────────────────────────────────
    if confirm "Install Jellyfin Media Server?" n; then
        run_cmd "Add Jellyfin repo" bash -c "
            wget -qO - https://repo.jellyfin.org/ubuntu/jellyfin_team.gpg.key 2>/dev/null | \
                gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg 2>/dev/null
            echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/jellyfin.gpg] https://repo.jellyfin.org/ubuntu noble main\" \
                > /etc/apt/sources.list.d/jellyfin.list 2>/dev/null
            apt-get update -qq
        " || warn "Jellyfin repo setup had issues"
        apt_install "Jellyfin" jellyfin || \
        flatpak_install "Jellyfin Server" org.jellyfin.JellyfinServer
    else
        track_item "declined" "Jellyfin"
    fi

    ok "Media stack installed"
}

# ==============================================================================
# SYSTEM PERFORMANCE TWEAKS
# ==============================================================================

system_tweaks() {
    section "System Performance Tweaks"

    # ── CPU Governor ──────────────────────────────────────────────────────────
    step "Setting CPU governor to 'performance'..."
    apt_install "cpufrequtils" cpufrequtils

    # Detect available governors
    local gov_path="/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors"
    if [[ -f "$gov_path" ]] && grep -q "performance" "$gov_path" 2>/dev/null; then
        run_cmd "Set CPU to performance governor" bash -c "
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                echo performance > \"\$cpu\" 2>/dev/null || true
            done
            echo 'GOVERNOR=\"performance\"' > /etc/default/cpufrequtils
        "
        ok "CPU governor: performance"
    else
        # schedutil is a good alternative on newer kernels
        info "Performance governor not available — using schedutil (kernel default)"
    fi

    # ── Swappiness ───────────────────────────────────────────────────────────
    step "Tuning kernel parameters..."
    local SYSCTL_CONF="/etc/sysctl.d/99-gaming-media-beast.conf"

    # Choose swappiness based on RAM
    local swappiness=10
    if [[ $RAM_GB -ge 16 ]]; then swappiness=5; fi
    if [[ $RAM_GB -ge 32 ]]; then swappiness=1; fi

    cat > "$SYSCTL_CONF" << EOF
# ── Gaming & Media Beast — Kernel Tuning ──────────────────────────────────
# Generated by gaming-media-beast.sh on $(date)

# Swappiness (lower = keep more in RAM)
vm.swappiness = $swappiness

# Dirty ratios (smoother writes)
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

# Inotify (needed for Steam, IDEs, etc.)
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 1024

# Network performance
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1

# Huge pages (gaming performance)
vm.nr_hugepages = 128

# Scheduler — latency tuning
# Note: sched_min_granularity_ns and sched_wakeup_granularity_ns are CFS-era
# tunables deprecated since kernel 6.6+ (Ubuntu 24.04 uses EEVDF scheduler).
# We guard these so they only apply if the kernel still supports them.
EOF

    # Only add deprecated CFS params on kernels older than 6.6
    local kern_maj kern_min
    kern_maj=$(uname -r | cut -d. -f1)
    kern_min=$(uname -r | cut -d. -f2)
    if [[ $kern_maj -lt 6 ]] || { [[ $kern_maj -eq 6 ]] && [[ $kern_min -lt 6 ]]; }; then
        cat >> "$SYSCTL_CONF" << 'EOF'
kernel.sched_min_granularity_ns = 500000
kernel.sched_wakeup_granularity_ns = 1000000
EOF
        info "Added CFS scheduler tuning (kernel $(uname -r) supports it)"
    else
        info "Skipped CFS sched tuning — kernel $(uname -r) uses EEVDF (6.6+), these params are no-ops"
    fi

    cat >> "$SYSCTL_CONF" << 'EOF'
kernel.shmmax = 17179869184
kernel.shmall = 4194304
EOF

    run_cmd "Apply sysctl settings" sysctl --system
    ok "Kernel parameters tuned (swappiness=$swappiness)"

    # ── IRQ affinity / CPU scheduling ────────────────────────────────────────
    apt_install "CPU scheduling tools" \
        irqbalance schedtool numactl \
        preload

    run_cmd "Enable irqbalance" bash -c "
        systemctl enable --now irqbalance 2>/dev/null || true
    "

    # ── Laptop-specific tweaks ────────────────────────────────────────────────
    if $IS_LAPTOP; then
        # Ubuntu 24.04 GNOME ships power-profiles-daemon which conflicts with TLP.
        # We must remove/mask PPD before installing TLP, otherwise both will fight
        # over CPU frequency control and systemd will log errors continuously.
        step "Resolving power management conflict (TLP vs power-profiles-daemon)..."
        if systemctl is-active power-profiles-daemon &>/dev/null 2>&1 || \
           dpkg -l power-profiles-daemon 2>/dev/null | grep -q '^ii'; then
            run_cmd "Mask power-profiles-daemon (conflicts with TLP)" bash -c "
                systemctl stop power-profiles-daemon 2>/dev/null || true
                systemctl mask power-profiles-daemon 2>/dev/null || true
            "
        fi
        apt_install "TLP (laptop power management)" tlp tlp-rdw || true
        run_cmd "Enable TLP" bash -c "
            systemctl enable --now tlp 2>/dev/null || true
        "
        ok "TLP (laptop power management) enabled"
    fi

    # ── Timer resolution (low-latency gaming) ─────────────────────────────────
    step "Setting high-resolution timer..."
    if [[ -f /sys/devices/system/clocksource/clocksource0/available_clocksource ]]; then
        local clocksource
        clocksource=$(cat /sys/devices/system/clocksource/clocksource0/available_clocksource)
        if echo "$clocksource" | grep -q "tsc"; then
            echo tsc > /sys/devices/system/clocksource/clocksource0/current_clocksource 2>/dev/null || true
            ok "Clocksource: TSC (high resolution)"
        fi
    fi

    # ── ZRAM (compressed swap in RAM) ────────────────────────────────────────
    if confirm "Enable ZRAM (faster swap in RAM — good for 8GB or less RAM)?" n; then
        apt_install "ZRAM" zram-config || \
        apt_install "ZRAM tools" zram-tools || true
    fi

    # ── Disable unnecessary services ──────────────────────────────────────────
    step "Disabling some resource-heavy services..."
    local services_to_disable=(
        "whoopsie"      # crash reporter
        "apport"        # error reporting
    )
    for svc in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$svc" &>/dev/null; then
            systemctl disable --now "$svc" 2>/dev/null || true
            info "Disabled: $svc"
        fi
    done

    ok "System performance tweaks applied"
}

# ==============================================================================
# ADDITIONAL TOOLS
# ==============================================================================

install_extras() {
    section "Additional Useful Tools"

    apt_install "System monitoring" \
        htop btop nvtop \
        lm-sensors \
        smartmontools \
        powertop \
        iotop

    apt_install "Archive + file tools" \
        file-roller \
        ark 2>/dev/null || true

    if confirm "Install GIMP (image editor)?" n; then
        apt_install "GIMP" gimp gimp-plugin-registry 2>/dev/null || \
        flatpak_install "GIMP" org.gimp.GIMP
    else
        track_item "declined" "GIMP"
    fi

    if confirm "Install Discord?" n; then
        flatpak_install "Discord" com.discordapp.Discord
    else
        track_item "declined" "Discord"
    fi

    # ── lm-sensors auto-detect ────────────────────────────────────────────────
    run_cmd "Detect hardware sensors" bash -c "
        yes | sensors-detect --auto 2>/dev/null || true
    "

    ok "Extra tools installed"
}

# ==============================================================================
# FINAL SUMMARY + RECOMMENDATIONS
# ==============================================================================

final_summary() {
    local SCRIPT_END
    SCRIPT_END=$(date '+%Y-%m-%d %H:%M:%S')
    log "=== SETUP COMPLETE at $SCRIPT_END ==="

    section "Installation Complete — Full Report"

    # ── Counts ────────────────────────────────────────────────────────────────
    local n_installed=${#TRACK_INSTALLED[@]}
    local n_skipped=${#TRACK_SKIPPED[@]}
    local n_failed=${#TRACK_FAILED[@]}
    local n_declined=${#TRACK_DECLINED[@]}

    echo ""
    echo -e "${BOLD}${WHITE}┌──────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${WHITE}│              🎮  BEAST SETUP — INSTALLATION REPORT  🎬               │${NC}"
    echo -e "${BOLD}${WHITE}├──────────────────────────────────────────────────────────────────────┤${NC}"
    printf "  ${BOLD}${WHITE}│${NC}  %-20s  ${LGREEN}%-3d installed${NC}  ${DIM}%-3d skipped${NC}  ${YELLOW}%-3d failed${NC}  ${DIM}%-3d declined${NC}  ${BOLD}${WHITE}│${NC}\n" \
        "Components:" "$n_installed" "$n_skipped" "$n_failed" "$n_declined"
    echo -e "${BOLD}${WHITE}├──────────────────────────────────────────────────────────────────────┤${NC}"

    # ── Installed ─────────────────────────────────────────────────────────────
    if [[ $n_installed -gt 0 ]]; then
        echo -e "  ${BOLD}${WHITE}│${NC}  ${BOLD}${LGREEN}✔  INSTALLED ($n_installed):${NC}"
        for item in "${TRACK_INSTALLED[@]}"; do
            printf "  ${BOLD}${WHITE}│${NC}     ${LGREEN}•${NC}  %s\n" "$item"
        done
        echo -e "  ${BOLD}${WHITE}│${NC}"
    fi

    # ── Already present / skipped ─────────────────────────────────────────────
    if [[ $n_skipped -gt 0 ]]; then
        echo -e "  ${BOLD}${WHITE}│${NC}  ${BOLD}${CYAN}⊘  ALREADY INSTALLED — SKIPPED ($n_skipped):${NC}"
        for item in "${TRACK_SKIPPED[@]}"; do
            printf "  ${BOLD}${WHITE}│${NC}     ${CYAN}•${NC}  %s\n" "$item"
        done
        echo -e "  ${BOLD}${WHITE}│${NC}"
    fi

    # ── Failed ────────────────────────────────────────────────────────────────
    if [[ $n_failed -gt 0 ]]; then
        echo -e "  ${BOLD}${WHITE}│${NC}  ${BOLD}${LRED}✘  FAILED ($n_failed) — check log for details:${NC}"
        for item in "${TRACK_FAILED[@]}"; do
            printf "  ${BOLD}${WHITE}│${NC}     ${LRED}•${NC}  %s\n" "$item"
        done
        echo -e "  ${BOLD}${WHITE}│${NC}"
    fi

    # ── Declined by user ──────────────────────────────────────────────────────
    if [[ $n_declined -gt 0 ]]; then
        echo -e "  ${BOLD}${WHITE}│${NC}  ${BOLD}${DIM}—  NOT INSTALLED (you chose no) ($n_declined):${NC}"
        for item in "${TRACK_DECLINED[@]}"; do
            printf "  ${BOLD}${WHITE}│${NC}     ${DIM}•  %s${NC}\n" "$item"
        done
        echo -e "  ${BOLD}${WHITE}│${NC}"
    fi

    # ── Hardware installed ─────────────────────────────────────────────────────
    echo -e "${BOLD}${WHITE}├──────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "  ${BOLD}${WHITE}│${NC}  ${BOLD}${WHITE}GPU Driver:${NC}  $(case "$GPU_VENDOR" in
        nvidia) echo "${LGREEN}NVIDIA (reboot required to activate)${NC}" ;;
        amd)    echo "${LGREEN}AMD Mesa${NC}" ;;
        intel)  echo "${LGREEN}Intel${NC}" ;;
        *)      echo "${YELLOW}Unknown vendor — generic Mesa installed${NC}" ;;
    esac)"
    echo -e "  ${BOLD}${WHITE}│${NC}  ${BOLD}${WHITE}Audio:${NC}       ${LGREEN}PipeWire + ALSA + JACK${NC}"
    if $HAS_FOCUSRITE; then
    echo -e "  ${BOLD}${WHITE}│${NC}  ${BOLD}${WHITE}Focusrite:${NC}   ${LGREEN}$FOCUSRITE_MODEL — alsa-scarlett-gui installed${NC}"
    fi
    echo -e "  ${BOLD}${WHITE}│${NC}  ${BOLD}${WHITE}Snapshot:${NC}    ${LGREEN}Timeshift backup created (safe to restore if needed)${NC}"

    # ── Tips ──────────────────────────────────────────────────────────────────
    echo -e "${BOLD}${WHITE}├──────────────────────────────────────────────────────────────────────┤${NC}"
    echo -e "  ${BOLD}${WHITE}│${NC}  ${BOLD}${WHITE}NEXT STEPS:${NC}"
    echo -e "  ${BOLD}${WHITE}│${NC}  1. Run: ${CYAN}sudo bash windows-app-support.sh${NC}  (Windows app layer)"
    echo -e "  ${BOLD}${WHITE}│${NC}  2. Reboot your system"
    if [[ "$GPU_VENDOR" == "nvidia" ]]; then
    echo -e "  ${BOLD}${WHITE}│${NC}  3. ${YELLOW}Watch for blue MOK screen on reboot — enter password: beast-setup${NC}"
    fi
    echo -e "  ${BOLD}${WHITE}│${NC}  4. Enable Proton: Steam → Settings → Compatibility → Enable Steam Play"
    echo -e "  ${BOLD}${WHITE}│${NC}  5. Add to Steam launch options: ${CYAN}MANGOHUD=1 gamemoderun %command%${NC}"
    echo -e "${BOLD}${WHITE}├──────────────────────────────────────────────────────────────────────┤${NC}"

    # ── Log path — always shown clearly ───────────────────────────────────────
    echo -e "  ${BOLD}${WHITE}│${NC}  ${BOLD}${WHITE}📋 Full install log:${NC}"
    echo -e "  ${BOLD}${WHITE}│${NC}     ${CYAN}${LOG_FILE}${NC}"
    echo -e "  ${BOLD}${WHITE}│${NC}     View: ${DIM}sudo cat ${LOG_FILE}${NC}"
    echo -e "  ${BOLD}${WHITE}│${NC}     Errors only: ${DIM}sudo grep -i 'error\\|fail\\|warn' ${LOG_FILE}${NC}"
    if [[ $n_failed -gt 0 ]]; then
    echo -e "  ${BOLD}${WHITE}│${NC}     ${LRED}⚠  $n_failed component(s) failed — review log before rebooting${NC}"
    fi
    echo -e "  ${BOLD}${WHITE}│${NC}  ${BOLD}${WHITE}Started:${NC}  $SCRIPT_START"
    echo -e "  ${BOLD}${WHITE}│${NC}  ${BOLD}${WHITE}Finished:${NC} $SCRIPT_END"
    echo -e "${BOLD}${WHITE}└──────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    if confirm "Reboot now to activate all changes?"; then
        info "Rebooting in 5 seconds..."
        sleep 5
        reboot
    else
        warn "Please reboot manually when ready: sudo reboot"
        show_log_path
    fi
}

# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================

main() {
    print_banner

    echo -e "  ${DIM}This script will set up your system for gaming and media production.${NC}"
    echo -e "  ${DIM}Estimated time: 20–60 minutes depending on internet speed.${NC}"
    echo ""
    echo -e "  ${BOLD}${CYAN}📋 All activity is logged to:${NC}"
    echo -e "  ${BOLD}${WHITE}   ${LOG_FILE}${NC}"
    echo -e "  ${DIM}   View live: ${CYAN}sudo tail -f ${LOG_FILE}${NC}"
    echo ""
    echo -e "  ${DIM}If the script is interrupted, simply re-run it —${NC}"
    echo -e "  ${DIM}already-installed components will be detected and skipped.${NC}"
    echo ""

    # ── Step 1: Safety checks ─────────────────────────────────────────────────
    preflight_checks

    # ── Step 2: Update & upgrade FIRST (clean base for everything else) ───────
    system_update_upgrade

    # ── Step 3: Snapshot AFTER upgrade (rollback point before drivers) ────────
    timeshift_snapshot

    # ── Step 4: Hardware detection (needs pciutils, installed in preflight) ───
    detect_cpu
    detect_gpu
    detect_audio
    detect_network
    print_hw_summary

    # ── Step 5: Secure Boot warning BEFORE any kernel modules are installed ───
    check_secure_boot

    # ── Step 6: Installation pipeline ────────────────────────────────────────
    prepare_system
    install_gpu_drivers
    install_network_drivers
    install_audio_stack
    install_focusrite
    install_gaming
    install_media
    system_tweaks
    install_extras

    # ── Done ──────────────────────────────────────────────────────────────────
    final_summary
}

main "$@"
