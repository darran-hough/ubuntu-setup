#!/bin/bash
# ---------------------------
# This is a bash script for configuring Ubuntu 22.04 for audio and gaming
# ---------------------------
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
snap-store --quit && sudo snap refresh snap-store

# ---------------------------
# Change to low latency Kernel
# ---------------------------
sudo apt install linux-image-lowlatency-hwe-22.04
sudo apt remove linux-image-generic-hwe-22.04 

# ---------------------------
# KXStudio
# ---------------------------
# Update software sources
sudo apt-get update
# Install required dependencies if needed
sudo apt-get install apt-transport-https gpgv wget
# Download package file
wget https://launchpad.net/~kxstudio-debian/+archive/kxstudio/+files/kxstudio-repos_11.1.0_all.deb
# Install it
sudo dpkg -i kxstudio-repos_11.1.0_all.deb
sudo apt update
sudo apt install cadence
sudo apt update && sudo apt upgrade && sudo apt dist-upgrade -y

# ---------------------------
# Pipewire
# ---------------------------
sudo apt install pipewire-audio-client-libraries libspa-0.2-bluetooth libspa-0.2-jack
sudo apt update
sudo apt install wireplumber pipewire-media-session-
sudo cp /usr/share/doc/pipewire/examples/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/
sudo cp /usr/share/doc/pipewire/examples/ld.so.conf.d/pipewire-jack-*.conf /etc/ld.so.conf.d/
sudo ldconfig
sudo apt remove pulseaudio-module-bluetooth
systemctl --user --now enable wireplumber.service
#to check status 
#pactl info

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
sudo apt install ubuntu-restricted-extras && sudo apt install vlc

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
# Heroic
# ---------------------------
sudo apt update
sudo apt install snapd
sudo snap install heroic

# ---------------------------
# Discord
# ---------------------------
wget "https://discord.com/api/download?platform=linux&format=deb" -O discord.deb
sudo dpkg -i discord.deb
sudo apt-get install -f

# ---------------------------
# Whatsapp
# ---------------------------
# sudo snap install whatsapp-for-linux

# ---------------------------
# Bitwig
# ---------------------------
# sudo apt install flatpak
# sudo apt install gnome-software-plugin-flatpak
# flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
# sudo apt update
# flatpak install flathub com.bitwig.BitwigStudio

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
