#!/usr/bin/env bash
set -euo pipefail

echo "🎹🎮 Minimal Ubuntu Music + Gaming Setup with Studio/Game Mode + VST Sync Tray"

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
# WINEHQ
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
export PATH="$HOME/.local/share:$PATH"
~/.local/share/winetricks -q corefonts
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
export PATH="$HOME/.local/share:$HOME/.local/share/yabridge:$PATH"

# VST PATHS
mkdir -p "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
mkdir -p "$HOME/.wine/drive_c/Program Files/Common Files/VST3"

~/.local/share/yabridge/yabridgectl add "$HOME/.wine/drive_c/Program Files/Steinberg/VstPlugins"
~/.local/share/yabridge/yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST2"
~/.local/share/yabridge/yabridgectl add "$HOME/.wine/drive_c/Program Files/Common Files/VST3"

############################################
# BITWIG STUDIO (DEB)
############################################
BITWIG_DEB=$(ls "$HOME"/Downloads/bitwig-studio-*.deb 2>/dev/null | head -n 1)
if [[ -f "$BITWIG_DEB" ]]; then
    echo "🎹 Installing Bitwig Studio from $BITWIG_DEB"
    sudo apt install -y "$BITWIG_DEB"
else
    echo "❌ Bitwig Studio .deb not found!"
    echo "➡ Download from https://www.bitwig.com/download/"
    echo "➡ Save to ~/Downloads and re-run this script"
    exit 1
fi

############################################
# STEAM + GAMEMODE
############################################
sudo add-apt-repository multiverse -y
sudo apt update

# Install Steam + GameMode via apt
if ! dpkg -s steam &>/dev/null; then
    echo "Installing Steam..."
    sudo apt install -y steam gamemode || true
fi

# Fallback: install Steam via Flatpak if apt fails
if ! command -v steam &>/dev/null; then
    echo "Steam apt package failed, installing via Flatpak..."
    sudo apt install -y flatpak
    flatpak install -y flathub com.valvesoftware.Steam
fi

############################################
# LOW LATENCY KERNEL
############################################
sudo apt install -y linux-lowlatency

############################################
# PIPEWIRE FOCUSRITE CONFIG
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
# STUDIO/GAME MODE + BUFFER SCRIPTS
############################################
mkdir -p ~/bin ~/.config/autostart ~/.local/share/applications

# Buffer control
cat <<'EOF' > ~/bin/pw-buffer.sh
#!/usr/bin/env bash
pw-metadata -n settings 0 clock.force-quantum "$1"
pw-metadata -n settings 0 clock.force-rate 48000
EOF

# Studio/Game Mode toggle
cat <<'EOF' > ~/bin/studio-mode
#!/usr/bin/env bash
if [[ "$1" == "studio" ]]; then
    ~/bin/pw-buffer.sh 64
    gamemoderun true
    echo "🎹 Studio Mode ON"
elif [[ "$1" == "game" ]]; then
    ~/bin/pw-buffer.sh 128
    echo "🎮 Game Mode ON"
else
    echo "Usage: studio-mode studio|game"
fi
EOF

# Bitwig project wrapper (per-project buffer)
cat <<'EOF' > ~/bin/bitwig-project.sh
#!/usr/bin/env bash
~/bin/pw-buffer.sh "$2"
gamemoderun bitwig-studio "$1"
~/bin/pw-buffer.sh 128
EOF

# Steam wrapper disables Studio Mode
cat <<'EOF' > ~/bin/steam-wrapper
#!/usr/bin/env bash
studio-mode game
exec /usr/bin/steam "$@"
EOF

# Studio VST Sync
cat <<'EOF' > ~/bin/studio-sync
#!/usr/bin/env bash
echo "🔄 Syncing Yabridge VSTs..."
~/.local/share/yabridge/yabridgectl sync
echo "✅ Yabridge VST Sync Complete!"
EOF

chmod +x ~/bin/*

# Override Steam desktop launcher
cp /usr/share/applications/steam.desktop ~/.local/share/applications/
sed -i "s|^Exec=.*|Exec=$HOME/bin/steam-wrapper %U|" ~/.local/share/applications/steam.desktop

############################################
# HIERARCHICAL STUDIO/GAME TRAY
############################################
sudo apt install -y python3-gi gir1.2-appindicator3-0.1

cat <<'PYEOF' > ~/bin/studio-tray.py
#!/usr/bin/env python3
import gi, subprocess, os
gi.require_version("Gtk", "3.0")
gi.require_version("AppIndicator3", "0.1")
from gi.repository import Gtk, AppIndicator3, GLib

current_mode = "Game"
current_buffer = "128"

icons = {
    "Studio": "audio-card",
    "Game": "applications-games"
}

def run_command(cmd, update_state=False, mode=None, buffer_size=None):
    subprocess.Popen(cmd)
    global current_mode, current_buffer
    if update_state:
        if mode:
            current_mode = mode
        if buffer_size:
            current_buffer = buffer_size
    update_tray()

def update_tray():
    tooltip_text = f"{current_mode} Mode – {current_buffer} samples"
    ind.set_label(tooltip_text, tooltip_text)
    ind.set_icon_full(icons.get(current_mode, "audio-card"), current_mode)

ind = AppIndicator3.Indicator.new(
    "studio-tray",
    icons[current_mode],
    AppIndicator3.IndicatorCategory.APPLICATION_STATUS
)
ind.set_status(AppIndicator3.IndicatorStatus.ACTIVE)

menu = Gtk.Menu()

studio_menu_item = Gtk.MenuItem(label="Studio")
studio_submenu = Gtk.Menu()

studio_enable = Gtk.MenuItem(label="Enable Studio Mode")
studio_enable.connect(
    "activate",
    lambda w: run_command(
        ["studio-mode", "studio"],
        update_state=True,
        mode="Studio",
        buffer_size="64"
    )
)
studio_submenu.append(studio_enable)

vst_sync = Gtk.MenuItem(label="VST Sync")
vst_sync.connect("activate", lambda w: run_command(["studio-sync"]))
studio_submenu.append(vst_sync)

buffer_menu_item = Gtk.MenuItem(label="Buffer Switching")
buffer_submenu = Gtk.Menu()
for size in ["32", "64", "128", "256"]:
    def make_cb(s):
        return lambda w: run_command(["pw-buffer.sh", s], update_state=True, buffer_size=s)
    item = Gtk.MenuItem(label=f"{size} samples")
    item.connect("activate", make_cb(size))
    buffer_submenu.append(item)
buffer_menu_item.set_submenu(buffer_submenu)
studio_submenu.append(buffer_menu_item)

studio_menu_item.set_submenu(studio_submenu)
menu.append(studio_menu_item)

game_item = Gtk.MenuItem(label="Game Mode")
game_item.connect(
    "activate",
    lambda w: run_command(
        ["studio-mode", "game"],
        update_state=True,
        mode="Game",
        buffer_size="128"
    )
)
menu.append(game_item)

exit_item = Gtk.MenuItem(label="Quit")
exit_item.connect("activate", lambda w: Gtk.main_quit())
menu.append(exit_item)

menu.show_all()
ind.set_menu(menu)
update_tray()
Gtk.main()
PYEOF

chmod +x ~/bin/studio-tray.py

# Autostart tray
cat <<EOF > ~/.config/autostart/studio-tray.desktop
[Desktop Entry]
Type=Application
Exec=$HOME/bin/studio-tray.py
Name=Studio/Game Mode + VST Sync
X-GNOME-Autostart-enabled=true
EOF

############################################
# FINAL CLEANUP
############################################
grep -qxF 'export PATH="$PATH:$HOME/bin"' ~/.bash_aliases || \
echo 'export PATH="$PATH:$HOME/bin"' >> ~/.bash_aliases

systemctl --user restart pipewire pipewire-pulse
sudo apt autoremove -y

echo "✅ MINIMAL SETUP COMPLETE — REBOOT RECOMMENDED"
