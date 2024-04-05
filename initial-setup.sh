#!/bin/bash
# ---------------------------
# This is a bash script for configuring Ubuntu 22.04 for audio and gaming
# ---------------------------

# Pre-requsites for focusrite
you will need to ensure that the focusrite audio are enabled by using the following
## 8i6 - sudo su echo " options snd_usb_audio vid=0x1235 pid=0x8213 device_setup=1" > /etc/modprobe.d/snd_usb_audio.conf
## 4i4 - sudo su echo " options snd_usb_audio vid=0x1235 pid=0x8212 device_setup=1" > /etc/modprobe.d/snd_usb_audio.conf


# NOTE: Execute this script by running the following command on your system:
# wget -O ~/initial-setup.sh https://raw.githubusercontent.com/darran-hough/ubuntu-setup/main/initial-setup.sh && chmod +x ~/initial-setup.sh && ~/initial-setup.sh


# Exit if any command fails
set -e

notify () {
  echo "--------------------------------------------------------------------"
  echo $1
  echo "--------------------------------------------------------------------"
}


# ---------------------------
# Update your system
# ---------------------------
sudo apt update && sudo apt upgrade && sudo apt dist-upgrade -y


# ---------------------------
# GPU AMD Drivers
# ---------------------------
wget https://repo.radeon.com/amdgpu-install/23.40.2/ubuntu/focal/amdgpu-install_6.0.60002-1_all.deb
sudo dpkg -i amdgpu-install_6.0.60002-1_all.deb


# ---------------------------
# Update Snap Store
# ---------------------------

killall snap-store 
sudo snap refresh snap-store


# ---------------------------
# Install PipeWire
# ---------------------------
# 1. **Check if PipeWire is installed**: PipeWire is pre-installed out-of-the-box in Ubuntu 22.04 and runs as a background service automatically. You can check its status by running the following command in the terminal:
# systemctl --user status pipewire pipewire-session-manager
# 2. **Install client libraries**: Although PipeWire is available out-of-the-box, it's not in use by default for audio output. To get started, open the terminal (Ctrl+Alt+T) and run the following command to install the client libraries:
sudo apt install pipewire-audio-client-libraries libspa-0.2-bluetooth libspa-0.2-jack
# 3. **Install wireplumber to replace pipewire-media-session**: The project maintainer now recommends the more advanced "wireplumber" session manager when using PipeWire as the system sound server. To install the package and remove "pipewire-media-session", run the following command in the terminal:
sudo apt install wireplumber pipewire-media-session-
# Note: There's a '-' at the end of the command which indicates to remove the package. The command will also install the required pipewire-pulse automatically.
# 4. **Copy configuration files**: For ALSA clients to be configured to output via PipeWire, run the following command to copy the configuration file:
sudo cp /usr/share/doc/pipewire/examples/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/
# For JACK client, run the following commands:
sudo cp /usr/share/doc/pipewire/examples/ld.so.conf.d/pipewire-jack-*.conf /etc/ld.so.conf.d/
sudo ldconfig
# For Bluetooth, just remove the pulseaudio-module-bluetooth package via command:
sudo apt remove pulseaudio-module-bluetooth
# And, finally enable the media session by running command:
systemctl --user --now enable wireplumber.service
# After restarting Ubuntu, you can verify the installation by running the command below in terminal. It should output Sound server: PulseAudio (on PipeWire x.x.x) indicates Pipewire is in use as sound output.
# pactl info



# ---------------------------
# Modify GRUB options
# threadirqs:
# mitigations=off:
# cpufreq.default_governor=performance:
# ---------------------------
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash threadirqs mitigations=off cpufreq.default_governor=performance"/g' /etc/default/grub
sudo update-grub


# ---------------------------
# sysctl.conf
# ---------------------------
# See https://wiki.linuxaudio.org/wiki/system_configuration for more information.
echo 'vm.swappiness=10
fs.inotify.max_user_watches=600000' | sudo tee -a /etc/sysctl.conf

# ---------------------------
# audio.conf
# ---------------------------
# See https://wiki.linuxaudio.org/wiki/system_configuration for more information.
echo '@audio - rtprio 90
@audio - memlock unlimited' | sudo tee -a /etc/security/limits.d/audio.conf

# ---------------------------
# Add the user to the audio group
# ---------------------------
sudo adduser $USER audio





# ---------------------------
# Wine (staging)
# This is required for yabridge
# See https://wiki.winehq.org/Ubuntu and https://wiki.winehq.org/Winetricks for additional information.
# ---------------------------
sudo dpkg --add-architecture i386 
sudo mkdir -pm755 /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key
sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources
sudo apt update && sudo apt install --install-recommends winehq-stable



# ---------------------------
# Install Winetricks
# See https://wiki.winehq.org/Ubuntu and https://wiki.winehq.org/Winetricks for additional information.
# ---------------------------
sudo apt install cabextract -y
mkdir -p ~/.local/share
wget -O winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
mv winetricks ~/.local/share
chmod +x ~/.local/share/winetricks
echo '' >> ~/.bash_aliases
echo '# Audio: winetricks' >> ~/.bash_aliases
echo 'export PATH="$PATH:$HOME/.local/share"' >> ~/.bash_aliases
. ~/.bash_aliases

# Base wine packages required for proper plugin functionality
winetricks corefonts

# Make a copy of .wine, as we will use this in the future as the base of
# new wine prefixes (when installing plugins)
cp -r ~/.wine ~/.wine-base

# ---------------------------
# Yabridge
# ---------------------------
wget -O yabridge.tar.gz https://github.com/robbert-vdh/yabridge/releases/download/5.1.0/yabridge-5.1.0.tar.gz
mkdir -p ~/.local/share
tar -C ~/.local/share -xavf yabridge.tar.gz
rm yabridge.tar.gz
echo '' >> ~/.bash_aliases
echo '# Audio: yabridge path' >> ~/.bash_aliases
echo 'export PATH="$PATH:$HOME/.local/share/yabridge"' >> ~/.bash_aliases
. ~/.bash_aliases
sudo apt install libnotify-bin -y


# Create common VST paths
mkdir -p "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST3"

# Add them into yabridge
yabridgectl add "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST3"


# ---------------------------
# Media codecs
# ---------------------------
sudo apt install ubuntu-restricted-extras


# ---------------------------
# VLC Media Player
# ---------------------------
sudo apt install vlc

# ---------------------------
# minimize dock items onclick
# ---------------------------
gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize'

# ---------------------------
# Backups and snapshots
# ---------------------------
sudo apt update
sudo apt install -y deja-dup

# ---------------------------
# Steam
# ---------------------------
sudo add-apt-repository multiverse
sudo apt update
sudo apt install steam
# ---------------------------
# Flatpak
# ---------------------------
sudo apt install flatpak

sudo add-apt-repository ppa:flatpak/stable
sudo apt update
sudo apt install flatpak

sudo apt install gnome-software-plugin-flatpak
# ---------------------------
# Heroic
# ---------------------------
flatpak install flathub io.github.heroic-games-launcher.Heroic

# ---------------------------
# Discord
# ---------------------------
wget "https://discord.com/api/download?platform=linux&format=deb" -O discord.deb
sudo dpkg -i discord.deb
sudo apt-get install -f

# ---------------------------
# Whatsapp
# ---------------------------
sudo snap install whatsapp-for-linux


# ---------------------------
# Bitwig
# ---------------------------
# Download .deb file and install with sudo apt

# ---------------------------
# install Chrome & remove Firefox
# ---------------------------
sudo snap remove firefox
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install ./google-chrome-stable_current_amd64.deb

# ---------------------------
# install piper
# ---------------------------
sudo apt update
sudo apt install piper

# ---------------------------
# Install Gimp
# ---------------------------
sudo apt update
sudo apt install -y gimp

# ---------------------------
# Cleanup
# ---------------------------
sudo apt autoremove

reboot
