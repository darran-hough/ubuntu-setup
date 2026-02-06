## download bitwig before running script: https://www.bitwig.com/download/

#!/usr/bin/env bash
set -e

echo "🎧🎮 Ubuntu Studio + Gaming Setup (Update-Safe)"

############################################
# AUDIO RT LIMITS
############################################
sudo tee /etc/security/limits.d/audio.conf >/dev/null <<EOF
@audio - rtprio 90
@audio - memlock unlimited
EOF

sudo usermod -aG audio "$USER"

############################################
# ENABLE i386 (Wine)
############################################
sudo dpkg --add-architecture i386

############################################
# WINEHQ (Ubuntu 24.04 Noble)
############################################
sudo mkdir -pm755 /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/winehq-archive.key \
https://dl.winehq.org/wine-builds/winehq.key

sudo wget -NP /etc/apt/sources.list.d/ \
https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources

sudo apt update
sudo apt install --install-recommends -y winehq-stable cabextract

############################################
# WINETRICKS
############################################
mkdir -p ~/.local/share
wget -O ~/.local/share/winetricks \
https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
chmod +x ~/.local/share/winetricks

grep -qxF 'export PATH="$PATH:$HOME/.local/share"' ~/.bash_aliases || \
echo 'export PATH="$PATH:$HOME/.local/share"' >> ~/.bash_aliases

winetricks -q corefonts
cp -r ~/.wine ~/.wine-base

############################################
# YABRIDGE
############################################
YABRIDGE_VERSION="5.1.1"
wget -O yabridge.tar.gz \
https://github.com/robbert-vdh/yabridge/releases/download/${YABRIDGE_VERSION}/yabridge-${YABRIDGE_VERSION}.tar.gz

mkdir -p ~/.local/share
tar -C ~/.local/share -xavf yabridge.tar.gz
rm yabridge.tar.gz

grep -qxF 'export PATH="$PATH:$HOME/.local/share/yabridge"' ~/.bash_aliases || \
echo 'export PATH="$PATH:$HOME/.local/share/yabridge"' >> ~/.bash_aliases

sudo apt install -y libnotify-bin

############################################
# VST PATHS
############################################
mkdir -p "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST3"

yabridgectl add "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST3"

############################################
# BITWIG STUDIO (DEB – REQUIRED FOR YABRIDGE)
############################################
BITWIG_DEB=$(ls "$HOME"/Downloads/bitwig-studio-*.deb 2>/dev/null | head -n 1)

if [[ -f "$BITWIG_DEB" ]]; then
    echo "🎹 Installing Bitwig Studio:"
    echo "   $BITWIG_DEB"
    sudo apt install -y "$BITWIG_DEB"
else
    echo "❌ Bitwig Studio .deb not found"
    echo "➡ Download from https://www.bitwig.com/download/"
    echo "➡ Save to ~/Downloads and re-run this script"
    exit 1
fi

############################################
# MEDIA + CREATIVE APPS
############################################
sudo apt install -y ubuntu-restricted-extras vlc deja-dup gimp piper

############################################
# STEAM + GAMING
############################################
sudo add-apt-repository multiverse -y
sudo apt update
sudo apt install -y steam gamemode

############################################
# FLATPAK + HEROIC
############################################
sudo apt install -y flatpak gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y flathub io.github.heroic-games-launcher.Heroic

############################################
# DISCORD
############################################
wget -O discord.deb "https://discord.com/api/download?platform=linux&format=deb"
sudo apt install -y ./discord.deb
rm discord.deb

############################################
# WHATSAPP
############################################
sudo snap install whatsapp-for-linux

############################################
# CHROME (REMOVE FIREFOX SNAP)
############################################
sudo snap remove firefox || true
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install -y ./google-chrome-stable_current_amd64.deb
rm google-chrome-stable_current_amd64.deb

############################################
# LOW LATENCY KERNEL
############################################
sudo apt install -y linux-lowlatency

############################################
# PIPEWIRE (FOCUSRITE-SAFE CONFIG)
############################################
mkdir -p ~/.config/pipewire/pipewire.conf.d
cat <<EOF > ~/.config/pipewire/pipewire.conf.d/99-focusrite.conf
context.properties = {
    default.clock.rate = 48000
    default.clock.allowed-rates = [ 48000 ]
    default.clock.quantum = 128
    default.clock.min-quantum = 32
    default.clock.max-quantum = 256
}
EOF

############################################
# STUDIO MODE + AUTOMATION
############################################
mkdir -p ~/bin ~/.config/autostart ~/.local/share/applications

cat <<'EOF' > ~/bin/pw-buffer.sh
#!/usr/bin/env bash
pw-metadata -n settings 0 clock.force-quantum "$1"
pw-metadata -n settings 0 clock.force-rate 48000
EOF

cat <<'EOF' > ~/bin/studio-mode
#!/usr/bin/env bash
if [[ "$1" == "on" ]]; then
  ~/bin/pw-buffer.sh 64
  gamemoderun true
  nvidia-settings -a '[gpu:0]/GpuPowerMizerMode=1' >/dev/null 2>&1 || true
elif [[ "$1" == "off" ]]; then
  ~/bin/pw-buffer.sh 128
  nvidia-settings -a '[gpu:0]/GpuPowerMizerMode=0' >/dev/null 2>&1 || true
else
  echo "Usage: studio-mode on|off"
fi
EOF

cat <<'EOF' > ~/bin/bitwig-project.sh
#!/usr/bin/env bash
~/bin/pw-buffer.sh "$2"
gamemoderun bitwig-studio "$1"
~/bin/pw-buffer.sh 128
EOF

cat <<'EOF' > ~/bin/steam-wrapper
#!/usr/bin/env bash
studio-mode off
exec /usr/bin/steam "$@"
EOF

chmod +x ~/bin/*

############################################
# STEAM DESKTOP OVERRIDE (USER-ONLY)
############################################
cp /usr/share/applications/steam.desktop ~/.local/share/applications/
sed -i "s|^Exec=.*|Exec=$HOME/bin/steam-wrapper %U|" ~/.local/share/applications/steam.desktop

############################################
# STUDIO MODE TRAY
############################################
sudo apt install -y python3-gi gir1.2-appindicator3-0.1

cat <<'EOF' > ~/bin/studio-tray.py
#!/usr/bin/env python3
import gi, subprocess
gi.require_version("Gtk","3.0")
gi.require_version("AppIndicator3","0.1")
from gi.repository import Gtk, AppIndicator3
ind = AppIndicator3.Indicator.new("studio","audio-card",0)
ind.set_status(1)
menu = Gtk.Menu()
for l,c in [("Studio ON",["studio-mode","on"]),("Studio OFF",["studio-mode","off"])]:
    i=Gtk.MenuItem(label=l)
    i.connect("activate",lambda w,c=c: subprocess.Popen(c))
    menu.append(i)
menu.show_all()
ind.set_menu(menu)
Gtk.main()
EOF

chmod +x ~/bin/studio-tray.py

cat <<EOF > ~/.config/autostart/studio-tray.desktop
[Desktop Entry]
Type=Application
Exec=$HOME/bin/studio-tray.py
Name=Studio Mode
X-GNOME-Autostart-enabled=true
EOF

############################################
# FINAL STEPS
############################################
grep -qxF 'export PATH="$PATH:$HOME/bin"' ~/.bash_aliases || \
echo 'export PATH="$PATH:$HOME/bin"' >> ~/.bash_aliases

systemctl --user restart pipewire pipewire-pulse
sudo apt autoremove -y

echo "✅ SETUP COMPLETE — REBOOT RECOMMENDED"
