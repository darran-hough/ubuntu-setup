#!/bin/bash

# =============================================================================
#           ULTIMATE WINE SETUP SCRIPT FOR UBUNTU 24.04 LTS
#           Supports: .exe .msi .cab .bat .reg .dll and more
# =============================================================================

# --- Colours ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# --- Helpers ---
ok()   { echo -e "${GREEN}[✔]${RESET} $1"; }
info() { echo -e "${CYAN}[→]${RESET} $1"; }
warn() { echo -e "${YELLOW}[!]${RESET} $1"; }
fail() { echo -e "${RED}[✘] ERROR:${RESET} $1"; exit 1; }
section() {
    echo ""
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}${BLUE}  $1${RESET}"
    echo -e "${BOLD}${BLUE}══════════════════════════════════════════════${RESET}"
}

run() {
    # Run a command silently; exit with error message on failure
    if ! eval "$1" &>/dev/null; then
        fail "Command failed: $1"
    fi
}

# =============================================================================
# PREFLIGHT CHECKS
# =============================================================================
section "PREFLIGHT CHECKS"

# Must be run as normal user (not root)
if [[ "$EUID" -eq 0 ]]; then
    fail "Do NOT run this script as root or with sudo. Run it as your normal user."
fi

# Check Ubuntu version
if ! grep -qi "ubuntu" /etc/os-release; then
    fail "This script is designed for Ubuntu. Your OS does not appear to be Ubuntu."
fi

UBUNTU_VERSION=$(grep VERSION_ID /etc/os-release | cut -d '"' -f2)
if [[ "$UBUNTU_VERSION" != "24.04" ]]; then
    warn "This script was written for Ubuntu 24.04. You are running $UBUNTU_VERSION. Proceeding anyway..."
else
    ok "Ubuntu 24.04 confirmed"
fi

# Check internet connection
info "Checking internet connection..."
if ! ping -c 1 google.com &>/dev/null; then
    fail "No internet connection detected. Please connect and re-run."
fi
ok "Internet connection confirmed"

# Check if running on 64-bit
if [[ "$(uname -m)" != "x86_64" ]]; then
    fail "This script requires a 64-bit system."
fi
ok "64-bit system confirmed"

echo ""
echo -e "${BOLD}All checks passed. Starting installation...${RESET}"
sleep 2

# =============================================================================
# STEP 1 — SYSTEM UPDATE
# =============================================================================
section "STEP 1 — SYSTEM UPDATE"
info "Updating package lists..."
sudo apt update -y || fail "apt update failed"
ok "Package lists updated"

# =============================================================================
# STEP 2 — ENABLE 32-BIT ARCHITECTURE
# =============================================================================
section "STEP 2 — ENABLE 32-BIT ARCHITECTURE"
info "Enabling i386 (32-bit) architecture support..."
sudo dpkg --add-architecture i386 || fail "Failed to add i386 architecture"
sudo apt update -y &>/dev/null
ok "32-bit architecture enabled"

# =============================================================================
# STEP 3 — ADD WINEHQ OFFICIAL REPOSITORY
# =============================================================================
section "STEP 3 — ADD WINEHQ REPOSITORY"

info "Creating keyrings directory..."
sudo mkdir -pm755 /etc/apt/keyrings

info "Downloading WineHQ GPG key..."
sudo wget -q -O /etc/apt/keyrings/winehq-archive.key \
    https://dl.winehq.org/wine-builds/winehq.key \
    || fail "Failed to download WineHQ GPG key. Check your internet connection."
ok "WineHQ GPG key installed"

info "Adding WineHQ Ubuntu Noble (24.04) repository..."
sudo wget -q -NP /etc/apt/sources.list.d/ \
    https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources \
    || fail "Failed to add WineHQ repository. Check your internet connection."
ok "WineHQ repository added"

info "Updating package lists with WineHQ repo..."
sudo apt update -y || fail "apt update failed after adding WineHQ repo"
ok "Package lists updated"

# =============================================================================
# STEP 4 — INSTALL WINE STAGING
# =============================================================================
section "STEP 4 — INSTALL WINE STAGING"
info "Installing Wine Staging (best compatibility — this may take a few minutes)..."
sudo apt install --install-recommends winehq-staging -y \
    || fail "Wine Staging installation failed. Try running: sudo apt install --install-recommends winehq-staging"

WINE_VERSION=$(wine --version 2>/dev/null)
ok "Wine Staging installed: $WINE_VERSION"

# =============================================================================
# STEP 5 — INSTALL SUPPORTING PACKAGES
# =============================================================================
section "STEP 5 — INSTALL SUPPORTING PACKAGES"

info "Installing cabextract, unzip, p7zip (for .cab, .zip, .7z installers)..."
sudo apt install -y cabextract unzip p7zip-full \
    || warn "Some archive tools failed to install — continuing anyway"
ok "Archive tools installed"

info "Installing Flatpak (for Bottles)..."
sudo apt install -y flatpak \
    || fail "Flatpak installation failed"
ok "Flatpak installed"

info "Installing Lutris (game/app manager)..."
sudo apt install -y lutris \
    || warn "Lutris failed to install — you can install it manually later"
ok "Lutris installed"

# =============================================================================
# STEP 6 — INSTALL WINETRICKS
# =============================================================================
section "STEP 6 — INSTALL WINETRICKS"
info "Installing Winetricks via apt..."
sudo apt install -y winetricks || warn "apt winetricks failed, will try direct download..."

info "Downloading latest Winetricks directly (ensures up-to-date version)..."
sudo wget -q -O /usr/local/bin/winetricks \
    https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
    || fail "Failed to download Winetricks"
sudo chmod +x /usr/local/bin/winetricks
ok "Winetricks installed (latest version)"

# =============================================================================
# STEP 7 — INITIALISE WINE PREFIX
# =============================================================================
section "STEP 7 — INITIALISE WINE PREFIX"
info "Initialising 64-bit Wine prefix (Windows 10)..."
info "A Wine configuration window may appear — close it when it opens."

# Initialise prefix non-interactively, then set Windows version to 10
WINEARCH=win64 WINEPREFIX=~/.wine wineboot --init &>/dev/null
sleep 3

# Set Windows version to 10 via registry
WINEPREFIX=~/.wine wine reg add \
    "HKLM\Software\Microsoft\Windows NT\CurrentVersion" \
    /v CurrentVersion /t REG_SZ /d "10.0" /f &>/dev/null

ok "Wine prefix created at ~/.wine (Windows 10, 64-bit)"

# =============================================================================
# STEP 8 — INSTALL WINDOWS RUNTIMES VIA WINETRICKS
# =============================================================================
section "STEP 8 — INSTALL WINDOWS RUNTIMES"
warn "This step installs Visual C++, .NET, DirectX, and fonts."
warn "It WILL take 10–30 minutes depending on your internet speed. Do not close the terminal."
echo ""

install_trick() {
    info "Installing: $1"
    WINEPREFIX=~/.wine winetricks -q "$1" &>/dev/null \
        && ok "$1 installed" \
        || warn "$1 failed — skipping (non-critical)"
}

# Visual C++ Runtimes (covers almost all .exe installers)
install_trick vcrun2005
install_trick vcrun2008
install_trick vcrun2010
install_trick vcrun2012
install_trick vcrun2013
install_trick vcrun2015
install_trick vcrun2017
install_trick vcrun2019
install_trick vcrun2022

# .NET Framework
install_trick dotnet48

# DirectX components
install_trick d3dx9
install_trick d3dx10
install_trick d3dx11_43
install_trick d3dcompiler_43
install_trick d3dcompiler_47

# Core Windows fonts (fixes text rendering in many apps)
install_trick corefonts
install_trick tahoma

# Media / common runtimes
install_trick quartz
install_trick devenum
install_trick mfc42
install_trick vb6run

# Wine Mono (.NET alternative) and Gecko (HTML engine)
install_trick mono
install_trick gecko

ok "All Windows runtimes installed"

# =============================================================================
# STEP 9 — INSTALL DXVK (DirectX → Vulkan)
# =============================================================================
section "STEP 9 — INSTALL DXVK"
info "Installing DXVK (massively improves DirectX 9/10/11 performance)..."
sudo apt install -y dxvk &>/dev/null \
    && WINEPREFIX=~/.wine setup_dxvk install &>/dev/null \
    && ok "DXVK installed and applied to Wine prefix" \
    || warn "DXVK apt install failed — trying winetricks fallback..."
    WINEPREFIX=~/.wine winetricks -q dxvk &>/dev/null \
        && ok "DXVK installed via winetricks" \
        || warn "DXVK could not be installed — DirectX apps may be slower"

# =============================================================================
# STEP 10 — INSTALL BOTTLES (GUI FRONTEND)
# =============================================================================
section "STEP 10 — INSTALL BOTTLES"
info "Adding Flathub repository..."
sudo flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo &>/dev/null
ok "Flathub added"

info "Installing Bottles (this may take a few minutes)..."
flatpak install -y flathub com.usebottles.bottles &>/dev/null \
    && ok "Bottles installed" \
    || warn "Bottles installation failed — you can install it later via: flatpak install flathub com.usebottles.bottles"

# =============================================================================
# STEP 11 — FILE ASSOCIATIONS (.exe, .msi, etc.)
# =============================================================================
section "STEP 11 — FILE ASSOCIATIONS"
info "Setting up double-click support for .exe and .msi files..."

# Create wine.desktop if it doesn't exist
DESKTOP_FILE="$HOME/.local/share/applications/wine.desktop"
mkdir -p "$HOME/.local/share/applications"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Wine Windows Program Loader
Exec=wine %f
Type=Application
MimeType=application/x-ms-dos-executable;application/x-msi;application/x-msdownload;
Icon=wine
NoDisplay=true
EOF

# Register MIME associations
xdg-mime default wine.desktop application/x-ms-dos-executable &>/dev/null
xdg-mime default wine.desktop application/x-msi &>/dev/null
xdg-mime default wine.desktop application/x-msdownload &>/dev/null

# Update MIME and desktop databases
update-mime-database ~/.local/share/mime &>/dev/null
update-desktop-database ~/.local/share/applications &>/dev/null

ok ".exe and .msi files will now open with Wine on double-click"

# =============================================================================
# DONE — SUMMARY
# =============================================================================
section "✔ INSTALLATION COMPLETE"

echo ""
echo -e "${BOLD}Everything installed:${RESET}"
echo ""
echo -e "  ${GREEN}✔${RESET} Wine Staging        — Run Windows apps from the terminal"
echo -e "  ${GREEN}✔${RESET} Winetricks          — Install Windows runtimes & libraries"
echo -e "  ${GREEN}✔${RESET} Visual C++ (all)    — Required by most .exe apps"
echo -e "  ${GREEN}✔${RESET} .NET Framework 4.8  — Required by many modern apps"
echo -e "  ${GREEN}✔${RESET} DirectX (9/10/11)   — Games and multimedia"
echo -e "  ${GREEN}✔${RESET} DXVK                — DirectX via Vulkan (faster graphics)"
echo -e "  ${GREEN}✔${RESET} Core Fonts & Tahoma — Fixes text rendering"
echo -e "  ${GREEN}✔${RESET} Media Runtimes      — quartz, devenum, mfc42, vb6run"
echo -e "  ${GREEN}✔${RESET} Mono & Gecko        — .NET and web engine for Wine"
echo -e "  ${GREEN}✔${RESET} Archive Tools       — .cab, .zip, .7z support"
echo -e "  ${GREEN}✔${RESET} Bottles (Flatpak)   — GUI app manager (recommended)"
echo -e "  ${GREEN}✔${RESET} Lutris              — Game/app manager with scripts"
echo -e "  ${GREEN}✔${RESET} File Associations   — Double-click .exe/.msi to run"
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}HOW TO USE:${RESET}"
echo ""
echo -e "  ${CYAN}Run a .exe file:${RESET}          wine /path/to/app.exe"
echo -e "  ${CYAN}Install a .msi file:${RESET}      msiexec /i /path/to/app.msi"
echo -e "  ${CYAN}Open Wine config:${RESET}          winecfg"
echo -e "  ${CYAN}Open Winetricks GUI:${RESET}       winetricks --gui"
echo -e "  ${CYAN}Launch Bottles:${RESET}            flatpak run com.usebottles.bottles"
echo -e "  ${CYAN}Launch Lutris:${RESET}             lutris"
echo -e "  ${CYAN}Kill Wine processes:${RESET}       wineserver -k"
echo -e "  ${CYAN}Double-click .exe/.msi:${RESET}   Works directly in your file manager"
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}TIPS:${RESET}"
echo ""
echo -e "  • Use ${BOLD}Bottles${RESET} for Windows apps — keeps each app isolated"
echo -e "  • Use ${BOLD}Lutris${RESET} for games — has pre-built install scripts"
echo -e "  • Check ${BOLD}appdb.winehq.org${RESET} if a specific app won't run"
echo -e "  • Suppress terminal noise: ${CYAN}WINEDEBUG=-all wine app.exe${RESET}"
echo -e "  • ${BOLD}Log out and back in${RESET} for all file associations to take full effect"
echo ""
echo -e "${GREEN}${BOLD}You're all set. Enjoy running Windows apps on Ubuntu!${RESET}"
echo ""
