#!/usr/bin/env bash
# ------------------------------------------------------------
# Ubuntu 24.04 – Audio & Gaming Optimisation (Bitwig‑only)
# Stable version with end‑prompt and error‑handling
# ------------------------------------------------------------
# Run as a normal user; the script will sudo where required.
# ------------------------------------------------------------

# -----------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------
LOGFILE="${HOME}/ubuntu-optimise.log"
exec > >(tee -a "${LOGFILE}") 2>&1   # duplicate all output to logfile

# -----------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------
notify() {
  echo "------------------------------------------------------------"
  echo "$1"
  echo "------------------------------------------------------------"
}

error_exit() {
  local rc=$?
  local last_cmd="${BASH_COMMAND}"
  echo "❌ ERROR: Command '${last_cmd}' exited with status ${rc}."
  echo "   Continuing with the next step (some features may be incomplete)."
}
trap error_exit ERR               # run error_exit on any non‑zero exit

# -----------------------------------------------------------------
# 0. Safety net – ensure script is run with Bash (not sh)
# -----------------------------------------------------------------
if [[ -z "$BASH_VERSION" ]]; then
  echo "This script requires Bash. Abort."
  exit 1
fi

# -----------------------------------------------------------------
# 1. Refresh Snap Store (optional)
# -----------------------------------------------------------------
notify "Refreshing Snap Store"
killall snap-store || true
sudo snap refresh snap-store || true

# -----------------------------------------------------------------
# 2. System update & upgrade
# -----------------------------------------------------------------
notify "Updating system packages"
sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y

# -----------------------------------------------------------------
# 3. (Optional) AMD GPU driver – keep only if you need a newer driver
# -----------------------------------------------------------------
# Uncomment the block below if you really need the newer AMDGPU driver.
# notify "Installing AMDGPU driver from official repo"
# wget https://repo.radeon.com/amdgpu-install/23.40.2/ubuntu/focal/amdgpu-install_6.0.60002-1_all.deb
# sudo dpkg -i amdgpu-install_6.0.60002-1_all.deb
# rm amdgpu-install_6.0.60002-1_all.deb

# -----------------------------------------------------------------
# 4. System tuning for low‑latency audio
# -----------------------------------------------------------------
notify "Applying sysctl and realtime audio limits"
echo -e "vm.swappiness=10\nfs.inotify.max_user_watches=600000" | sudo tee -a /etc/sysctl.conf >/dev/null
echo -e "@audio - rtprio 90\n@audio - memlock unlimited" | sudo tee -a /etc/security/limits.d/audio.conf >/dev/null
sudo adduser "$USER" audio || true   # may already be a member

# -----------------------------------------------------------------
# 5. CPU performance governor (keep CPU at max frequency)
# -----------------------------------------------------------------
notify "Installing cpupower and setting governor to performance"
sudo apt install -y cpupower
sudo cpupower frequency-set -g performance

# Persist the setting across reboots via systemd
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
# 6. Install realtime audio stack (PipeWire + JACK)
# -----------------------------------------------------------------
notify "Installing PipeWire, JACK and realtime kit"
sudo apt install -y \
    pipewire pipewire-audio-client-libraries pipewire-pulse wireplumber \
    jackd2 libjack-jackd2-0 realtimekit

# Enable PipeWire as the default audio server
systemctl --user enable --now pipewire pipewire-pulse

# Optional: allow PulseAudio apps to talk to JACK
sudo apt install -y pulseaudio-module-jack || true

# -----------------------------------------------------------------
# 7. Install Wine (stable) + winetricks
# -----------------------------------------------------------------
notify "Setting up Wine and winetricks"
sudo dpkg --add-architecture i386
sudo mkdir -p /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources
sudo apt update
sudo apt install --install-recommends -y winehq-stable

# Install winetricks locally
sudo apt install -y cabextract
mkdir -p "$HOME/.local/share"
wget -O "$HOME/.local/share/winetricks" https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
chmod +x "$HOME/.local/share/winetricks"

{
  echo ''
  echo '# Audio: winetricks'
  echo 'export PATH="\$PATH:\$HOME/.local/share"'
} >> "$HOME/.bash_aliases"
source "$HOME/.bash_aliases"

"$HOME/.local/share/winetricks" corefonts

# Keep a clean baseline .wine directory
cp -r "$HOME/.wine" "$HOME/.wine-base" || true

# -----------------------------------------------------------------
# 8. Install Yabridge (VST bridge for Wine)
# -----------------------------------------------------------------
notify "Installing Yabridge"
YABRIDGE_URL="https://github.com/robbert-vdh/yabridge/releases/download/5.1.0/yabridge-5.1.0.tar.gz"
wget -O "$HOME/yabridge.tar.gz" "$YABRIDGE_URL"
mkdir -p "$HOME/.local/share"
tar -C "$HOME/.local/share" -xavf "$HOME/yabridge.tar.gz"
rm "$HOME/yabridge.tar.gz"

{
  echo ''
  echo '# Audio: yabridge path'
  echo 'export PATH="\$PATH:\$HOME/.local/share/yabridge"'
} >> "$HOME/.bash_aliases"
source "$HOME/.bash_aliases"

sudo apt install -y libnotify-bin || true

# Create VST directories inside the Wine prefix
mkdir -p "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST3"

# Register those folders with yabridge
yabridgectl add "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST3"

# -----------------------------------------------------------------
# 9. Media codecs & common desktop apps
# -----------------------------------------------------------------
notify "Installing media codecs and common applications"
sudo apt install -y ubuntu-restricted-extras vlc gimp deja-dup

# Chrome (replace Firefox snap)
sudo snap remove firefox || true
wget -O "$HOME/google-chrome-stable_current_amd64.deb" \
     https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install -y "./$HOME/google-chrome-stable_current_amd64.deb"
rm "$HOME/google-chrome-stable_current_amd64.deb"

# Piper (gaming‑mouse configuration)
sudo apt install -y piper || true

# -----------------------------------------------------------------
# 10. Gaming platforms & performance tools
# -----------------------------------------------------------------
notify "Setting up Steam, Flatpak, GameMode and Vulkan"
sudo add-apt-repository -y multiverse
sudo apt update
sudo apt install -y steam

# Flatpak + Flathub
sudo apt install -y flatpak gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# GameMode – lets games request higher performance profiles
sudo apt install -y gamemode libgamemode0 || true

# Vulkan drivers (covers AMD/NVIDIA/Intel)
sudo apt install -y mesa-vulkan-drivers vulkan-tools

# OBS Studio (record/stream gameplay)
sudo apt install -y obs-studio || true

# -----------------------------------------------------------------
# 11. Bitwig Studio – download & install the latest .deb
# -----------------------------------------------------------------
notify "Downloading and installing Bitwig Studio"
# Grab the latest public download page, parse the .deb URL, and install.
BITWIG_DEB_URL=$(curl -s https://downloads.bitwig.com/stable/ | \
                grep -Eo 'https://[^"]+bitwig-studio-[0-9]+.[0-9]+.[0-9]+-linux-x86_64\.deb' | head -n1)

if [[ -z "$BITWIG_DEB_URL" ]]; then
  echo "⚠️ Could not locate Bitwig .deb URL automatically."
  echo "Please visit https://www.bitwig.com/en/download.html, download the Linux .deb, place it in \$HOME, and rerun the script."
else
  wget -O "$HOME/bitwig-studio.deb" "$BITWIG_DEB_URL"
  sudo apt install -y "./$HOME/bitwig-studio.deb"
  rm "$HOME/bitwig-studio.deb"
fi

# -----------------------------------------------------------------
# 12. GNOME desktop tweaks
# -----------------------------------------------------------------
notify "Applying GNOME Dock tweak (click‑to‑minimize)"
gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize' || true

# -----------------------------------------------------------------
# 13. CoreCtrl – GPU power‑profile manager (optional)
# -----------------------------------------------------------------
notify "Installing CoreCtrl (GPU power‑profile UI)"
sudo add-apt-repository -y ppa:ernstp/graphics-drivers
sudo apt update
sudo apt install -y corectrl || true

# -----------------------------------------------------------------
# 14. Final cleanup
# -----------------------------------------------------------------
notify "Cleaning up"
sudo apt autoremove -y || true

# -----------------------------------------------------------------
# 15. Prompt for reboot
# -----------------------------------------------------------------
while true; do
  read -rp "All done! Do you want to reboot now? [Y/n] " yn
  case $yn in
    [Yy]*|'' )
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
