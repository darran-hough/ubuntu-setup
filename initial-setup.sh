#!/usr/bin/env bash
# ----------------------------------------------------------------------
# Ubuntu 24.04 – Audio & Gaming Optimisation (Bitwig‑only)
# Updated 2026‑02‑06 – fixes for missing repos, packages and utilities
# ----------------------------------------------------------------------
# Run as a normal (non‑root) user; the script will sudo where required.
# ----------------------------------------------------------------------

# --------------------------------------------------------------
# 0. Basic safety & environment
# --------------------------------------------------------------
set -euo pipefail          # abort on errors, undefined vars, pipe failures
IFS=$'\n\t'                # sane field splitting

# Restore a normal PATH in case the caller stripped it (e.g. CI sandbox)
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

# Helper to print a highlighted banner
banner() { echo -e "\n\033[1;34m===== $1 =====\033[0m\n"; }

# -----------------------------------------------------------------
# 1. Logging – duplicate all output to a logfile in $HOME
# -----------------------------------------------------------------
LOGFILE="${HOME}/ubuntu-optimise.log"
exec > >(tee -a "${LOGFILE}") 2>&1   # stdout+stderr → console + logfile

# -----------------------------------------------------------------
# 2. Helper functions
# -----------------------------------------------------------------
notify() {
    echo "------------------------------------------------------------"
    echo "$1"
    echo "------------------------------------------------------------"
}

error_exit() {
    local rc=$?
    local cmd="${BASH_COMMAND}"
    echo "❌ ERROR: Command '${cmd}' exited with status ${rc}."
    echo "   Continuing with the next step (some features may be incomplete)."
}
trap error_exit ERR   # run error_exit on any non‑zero exit status

# -----------------------------------------------------------------
# 3. Verify that essential utilities exist
# -----------------------------------------------------------------
missing_utils=()
for util in sudo apt-get wget curl grep head gsettings tar; do
    command -v "$util" >/dev/null 2>&1 || missing_utils+=("$util")
done
if (( ${#missing_utils[@]} )); then
    echo "⚠️  The following required utilities are missing: ${missing_utils[*]}"
    echo "Attempting to install them now..."
    sudo apt-get update
    sudo apt-get install -y "${missing_utils[@]}"
fi

# -----------------------------------------------------------------
# 4. Enable the Ubuntu repositories we need
# -----------------------------------------------------------------
banner "Enabling Ubuntu repositories"
sudo add-apt-repository -y universe multiverse restricted
sudo apt-get update

# -----------------------------------------------------------------
# 5. Refresh Snap Store (optional)
# -----------------------------------------------------------------
notify "Refreshing Snap Store"
killall snap-store || true
sudo snap refresh snap-store || true

# -----------------------------------------------------------------
# 6. Full system upgrade
# -----------------------------------------------------------------
notify "Updating system packages"
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y dist-upgrade

# -----------------------------------------------------------------
# 7. Low‑latency audio tuning (sysctl + limits)
# -----------------------------------------------------------------
notify "Applying sysctl tweaks and realtime audio limits"
{
    echo "vm.swappiness=10"
    echo "fs.inotify.max_user_watches=600000"
} | sudo tee -a /etc/sysctl.conf >/dev/null

{
    echo "@audio - rtprio 90"
    echo "@audio - memlock unlimited"
} | sudo tee -a /etc/security/limits.d/audio.conf >/dev/null

# Ensure the current user is in the `audio` group (needed for real‑time priority)
sudo usermod -aG audio "$USER"
newgrp audio  # apply group change without logout

# -----------------------------------------------------------------
# 8. CPU performance governor (keep CPU at max frequency)
# -----------------------------------------------------------------
notify "Installing cpupower and setting governor to performance"

# On Ubuntu 24.04 the binary lives in the linux‑tools package matching the kernel
sudo apt-get install -y linux-tools-common "linux-tools-$(uname -r)" cpupower

# Set the governor now
sudo cpupower frequency-set -g performance

# Persist the setting across reboots via a systemd service
cat <<'EOF' | sudo tee /etc/systemd/system/cpupower-performance.service >/dev/null
[Unit]
Description=Set CPU governor to performance
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/cpupower frequency-set -g performance
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now cpupower-performance.service

# -----------------------------------------------------------------
# 9. Install realtime audio stack (PipeWire + JACK)
# -----------------------------------------------------------------
notify "Installing PipeWire, JACK and realtime‑kit"

# Install PipeWire and JACK (pulseaudio‑module‑jack is optional)
sudo apt-get install -y \
    pipewire pipewire-audio-client-libraries pipewire-pulse wireplumber \
    jackd2 libjack-jackd2-0 realtimekit

# Enable PipeWire for the current user
systemctl --user enable --now pipewire pipewire-pulse

# Optional: allow Pulseaudio apps to talk to JACK (keeps compatibility)
sudo apt-get install -y pulseaudio-module-jack || true

# -----------------------------------------------------------------
# 10. Install Wine (stable) + winetricks
# -----------------------------------------------------------------
notify "Setting up Wine and winetricks"

# Enable 32‑bit architecture (required for many Windows VSTs)
sudo dpkg --add-architecture i386
sudo apt-get update

# Add the official WineHQ repository (Ubuntu 24.04 ships a recent stable build)
wget -O - https://dl.winehq.org/wine-builds/winehq.key | sudo apt-key add -
sudo apt-add-repository -y "deb https://dl.winehq.org/wine-builds/ubuntu/ $(lsb_release -cs) main"
sudo apt-get update
sudo apt-get install -y --install-recommends winehq-stable

# Install winetricks from the Ubuntu archive (much simpler than pulling the raw script)
sudo apt-get install -y winetricks
# Install a minimal set of Windows fonts – useful for many VST GUIs
winetricks corefonts

# Keep a clean baseline .wine directory for future restores
cp -a "$HOME/.wine" "$HOME/.wine-base" 2>/dev/null || true

# -----------------------------------------------------------------
# 11. Install Yabridge (VST bridge for Wine)
# -----------------------------------------------------------------
notify "Installing Yabridge (VST bridge)"

# Prefer the packaged version if it exists (available in universe for 24.04)
if ! command -v yabridge >/dev/null 2>&1; then
    if sudo apt-get install -y yabridge; then
        echo "✅ Installed yabridge from the Ubuntu archive"
    else
        echo "⚠️  Package yabridge not available – falling back to upstream tarball"
        YABRIDGE_URL="https://github.com/robbert-vdh/yabridge/releases/download/5.1.0/yabridge-5.1.0.tar.gz"
        wget -O "$HOME/yabridge.tar.gz" "$YABRIDGE_URL"
        mkdir -p "$HOME/.local/share"
        tar -C "$HOME/.local/share" -xavf "$HOME/yabridge.tar.gz"
        rm "$HOME/yabridge.tar.gz"
        # Add yabridge to PATH for the current session
        export PATH="$HOME/.local/share/yabridge:$PATH"
    fi
fi

# Ensure the VST directories exist inside the Wine prefix
mkdir -p "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST3"

# Register those folders with yabridge (works for both packaged & tarball versions)
yabridgectl add "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST3"

# -----------------------------------------------------------------
# 12. Media codecs & common desktop apps
# -----------------------------------------------------------------
notify "Installing media codecs and common applications"

sudo apt-get install -y \
    ubuntu-restricted-extras vlc gimp deja-dup

# Replace the Firefox snap with Google Chrome (deb package)
sudo snap remove firefox || true
wget -O "$HOME/google-chrome-stable_current_amd64.deb" \
     https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt-get install -y "$HOME/google-chrome-stable_current_amd64.deb"
rm "$HOME/google-chrome-stable_current_amd64.deb"

# Piper – gaming‑mouse configuration (optional, ignore failure)
sudo apt-get install -y piper || true

# -----------------------------------------------------------------
# 13. Gaming platforms & performance tools
# -----------------------------------------------------------------
notify "Setting up Steam, Flatpak, GameMode and Vulkan"

# Steam (adds the multiverse repo automatically, but we already enabled it)
sudo apt-get install -y steam

# Flatpak + Flathub
sudo apt-get install -y flatpak gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# GameMode – lets games request higher performance profiles
sudo apt-get install -y gamemode libgamemode0 || true

# Vulkan drivers (covers AMD/NVIDIA/Intel)
sudo apt-get install -y mesa-vulkan-drivers vulkan-tools

# OBS Studio (record/stream gameplay)
sudo apt-get install -y obs-studio || true

# -----------------------------------------------------------------
# 14. Bitwig Studio – download & install the latest .deb
# -----------------------------------------------------------------
notify "Downloading and installing Bitwig Studio"

# Grab the latest public download page, parse the .deb URL, and install.
BITWIG_DEB_URL=$(curl -s https://downloads.bitwig.com/stable/ |
    grep -Eo 'https://[^"]+bitwig-studio-[0-9]+\.[0-9]+\.[0-9]+-linux-x86_64\.deb' |
    head -n1)

if [[ -z "$BITWIG_DEB_URL" ]]; then
    echo "⚠️  Could not locate Bitwig .deb URL automatically."
    echo "Please visit https://www.bitwig.com/en/download.html, download the Linux .deb,"
    echo "place it in \$HOME, and re‑run the script."
else
    wget -O "$HOME/bitwig-studio.deb" "$BITWIG_DEB_URL"
    sudo apt-get install -y "$HOME/bitwig-studio.deb"
    rm "$HOME/bitwig-studio.deb"
fi

# -----------------------------------------------------------------
# 15. GNOME desktop tweaks
# -----------------------------------------------------------------
notify "Applying GNOME Dock tweak (click‑to‑minimize)"
gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize' || true

# -----------------------------------------------------------------
# 16. CoreCtrl – GPU power‑profile manager (optional)
# -----------------------------------------------------------------
notify "Installing CoreCtrl (GPU power‑profile UI)"
sudo add-apt-repository -y ppa:ernstp/graphics-drivers
sudo apt-get update
sudo apt-get install -y corectrl || true

# -----------------------------------------------------------------
# 17. Final cleanup
# -----------------------------------------------------------------
notify "Cleaning up"
sudo apt-get autoremove -y || true
sudo apt-get autoclean -y || true

# -----------------------------------------------------------------
# 18. Prompt for reboot
# -----------------------------------------------------------------
while true; do
    read -rp "All done! Do you want to reboot now? [Y/n] " yn
    case $yn in
        [Yy]*|'' )   # default = yes
            notify "Rebooting now…"
            sudo reboot
            break
            ;;
        [Nn]* )
            notify "Reboot postponed. Remember to reboot later for all changes to take effect."
            break
            ;;
        * )
            echo "Please answer Y (yes) or N (no)."
            ;;
    esac
done
