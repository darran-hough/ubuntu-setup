#!/usr/bin/env bash
# ------------------------------------------------------------
# Ubuntu 24.04 – Audio & Gaming Setup (Kernel‑agnostic version)
# ------------------------------------------------------------

set -e   # exit on any error

notify () {
  echo "------------------------------------------------------------"
  echo "$1"
  echo "------------------------------------------------------------"
}

# -----------------------------------------------------------------
# 1. Refresh Snap Store (optional but kept from original)
# -----------------------------------------------------------------
notify "Refreshing Snap Store"
killall snap-store || true
sudo snap refresh snap-store

# -----------------------------------------------------------------
# 2. System update & upgrade
# -----------------------------------------------------------------
notify "Updating system packages"
sudo apt update && sudo apt upgrade -y && sudo apt dist-upgrade -y

# -----------------------------------------------------------------
# 3. (Optional) AMD GPU driver – keep only if you need a newer driver
# -----------------------------------------------------------------
# Comment out the whole block if you prefer Ubuntu's default driver.
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

# Add current user to the audio group (needed for real‑time scheduling)
sudo adduser "$USER" audio

# -----------------------------------------------------------------
# 5. Install Wine (staging) + winetricks
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

# Add winetricks to PATH via .bash_aliases (creates if missing)
{
  echo ''
  echo '# Audio: winetricks'
  echo 'export PATH="\$PATH:\$HOME/.local/share"'
} >> "$HOME/.bash_aliases"
source "$HOME/.bash_aliases"

# Install a minimal set of fonts (adjust as needed)
"$HOME/.local/share/winetricks" corefonts

# Preserve a clean baseline .wine directory
cp -r "$HOME/.wine" "$HOME/.wine-base"

# -----------------------------------------------------------------
# 6. Install Yabridge (VST bridge for Wine)
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

# Install libnotify (used by yabridge UI)
sudo apt install -y libnotify-bin

# Create standard VST directories inside the Wine prefix
mkdir -p "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST3"

# Register those folders with yabridge
yabridgectl add "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST3"

# -----------------------------------------------------------------
# 7. Media codecs & common desktop apps
# -----------------------------------------------------------------
notify "Installing media codecs and common applications"
sudo apt install -y ubuntu-restricted-extras vlc gimp deja-dup

# Chrome (replace Firefox snap)
sudo snap remove firefox || true
wget -O "$HOME/google-chrome-stable_current_amd64.deb" \
     https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install -y "./$HOME/google-chrome-stable_current_amd64.deb"
rm "$HOME/google-chrome-stable_current_amd64.deb"

# Piper (for gaming mouse configuration)
sudo apt install -y piper

# -----------------------------------------------------------------
# 8. Gaming platforms
# -----------------------------------------------------------------
notify "Setting up Steam, Flatpak, and related repos"
sudo add-apt-repository -y multiverse
sudo apt update
sudo apt install -y steam

# Flatpak + Flathub
sudo apt install -y flatpak gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# -----------------------------------------------------------------
# 9. GNOME desktop tweaks
# -----------------------------------------------------------------
notify "Applying GNOME Dock tweak (click‑to‑minimize)"
gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize'

# -----------------------------------------------------------------
# 10. Final cleanup
# -----------------------------------------------------------------
notify "Cleaning up"
sudo apt autoremove -y

notify "Setup complete – you may now reboot"
# Uncomment the next line if you want the script to reboot automatically:
# sudo reboot
