#!/usr/bin/env bash
set -Eeuo pipefail

############################################################
# Ubuntu 24.04 Ultimate Hybrid Audio + Gaming Setup
############################################################

DRY_RUN=false
[[ "${1:-}" == "--dryrun" ]] && DRY_RUN=true

USER_NAME="${SUDO_USER:-$USER}"
HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"
WINEPREFIX="$HOME_DIR/.wine-yabridge"
YABRIDGE_DIR="$HOME_DIR/.yabridge"

log(){ echo -e "\e[1;32m[INFO]\e[0m $*"; }
warn(){ echo -e "\e[1;33m[WARN]\e[0m $*"; }

run(){
    if $DRY_RUN; then
        echo "[DRYRUN] $*"
    else
        "$@"
    fi
}

apt_install(){
    run sudo apt-get install -y --no-install-recommends "$@"
}

############################################################
# SYSTEM UPDATE
############################################################

log "Updating system"
run sudo apt-get update
run sudo apt-get dist-upgrade -y

############################################################
# LOW LATENCY KERNEL
############################################################

if ! dpkg -s linux-lowlatency &>/dev/null; then
    apt_install linux-lowlatency linux-headers-lowlatency
fi

############################################################
# CORE PACKAGES
############################################################

apt_install \
pipewire pipewire-jack wireplumber \
alsa-utils rtkit gamemode \
winetricks cabextract unzip wget gnupg jq curl \
python3-pyqt6 python3-pip \
gamescope mangohud vkbasalt latencytop \
rtirq-init \
linux-tools-common linux-tools-$(uname -r)

run systemctl --user enable pipewire pipewire-pulse wireplumber --now

############################################################
# REALTIME AUDIO PERMISSIONS
############################################################

run sudo install -Dm644 /dev/stdin /etc/security/limits.d/audio.conf <<EOF
@audio - rtprio 95
@audio - memlock unlimited
@audio - nice -19
EOF

run sudo usermod -aG audio "$USER_NAME"

############################################################
# PIPEWIRE LOW LATENCY
############################################################

mkdir -p "$HOME_DIR/.config/pipewire/pipewire.conf.d"

cat > "$HOME_DIR/.config/pipewire/pipewire.conf.d/99-lowlatency.conf" <<EOF
context.properties = {
 default.clock.rate = 48000
 default.clock.quantum = 64
 default.clock.min-quantum = 32
 default.clock.max-quantum = 256
 realtime.priority = 88
}
EOF

############################################################
# AMD CPU + USB AUDIO LATENCY
############################################################

sudo tee /etc/modprobe.d/amd-usb-audio.conf > /dev/null <<EOF
options snd_usb_audio nrpacks=1
EOF

############################################################
# NVIDIA PERFORMANCE + WAYLAND
############################################################

sudo tee /etc/modprobe.d/nvidia-performance.conf > /dev/null <<EOF
options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_RegistryDwords="PerfLevelSrc=0x2222"
EOF

sudo tee /etc/modprobe.d/nvidia-drm.conf > /dev/null <<EOF
options nvidia-drm modeset=1
EOF

run sudo update-initramfs -u || true

############################################################
# RTIRQ PRIORITY
############################################################

sudo tee /etc/default/rtirq > /dev/null <<EOF
RTIRQ_NAME_LIST="snd usb nvidia"
RTIRQ_PRIO_HIGH=90
RTIRQ_PRIO_LOW=60
EOF

run sudo systemctl enable rtirq || true

############################################################
# MANGOHUD CONFIG
############################################################

mkdir -p "$HOME_DIR/.config/MangoHud"

cat > "$HOME_DIR/.config/MangoHud/MangoHud.conf" <<EOF
fps
frametime
cpu_stats
gpu_stats
ram
vram
EOF

############################################################
# VKBASALT CONFIG
############################################################

mkdir -p "$HOME_DIR/.config/vkBasalt"

cat > "$HOME_DIR/.config/vkBasalt/vkBasalt.conf" <<EOF
effects = cas
casSharpness = 0.5
EOF

############################################################
# PIPEWIRE PROFILE SCRIPTS
############################################################

mkdir -p "$HOME_DIR/.local/bin"

cat > "$HOME_DIR/.local/bin/pw-daw.sh" <<EOF
#!/usr/bin/env bash
pw-metadata -n settings 0 clock.force-rate 48000
pw-metadata -n settings 0 clock.force-quantum 64
EOF

cat > "$HOME_DIR/.local/bin/pw-game.sh" <<EOF
#!/usr/bin/env bash
pw-metadata -n settings 0 clock.force-rate 48000
pw-metadata -n settings 0 clock.force-quantum 256
EOF

############################################################
# CPU GOVERNOR SCRIPTS
############################################################

cat > "$HOME_DIR/.local/bin/performance-mode.sh" <<'EOF'
#!/usr/bin/env bash
sudo cpupower frequency-set -g performance
for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
 echo performance | sudo tee "$f" >/dev/null 2>&1 || true
done
EOF

cat > "$HOME_DIR/.local/bin/studio-mode.sh" <<'EOF'
#!/usr/bin/env bash
sudo cpupower frequency-set -g schedutil
for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
 echo balance_performance | sudo tee "$f" >/dev/null 2>&1 || true
done
~/.local/bin/pw-daw.sh
EOF

chmod +x "$HOME_DIR/.local/bin/"*.sh

############################################################
# GAMESCOPE WRAPPER
############################################################

cat > "$HOME_DIR/.local/bin/gamescope-launch.sh" <<'EOF'
#!/usr/bin/env bash

~/.local/bin/performance-mode.sh

export MANGOHUD=1
export ENABLE_VKBASALT=1
export __GL_SYNC_TO_VBLANK=0
export __GL_GSYNC_ALLOWED=1
export __GL_VRR_ALLOWED=1

exec gamescope -f -r 144 --adaptive-sync -- "$@"
EOF

chmod +x "$HOME_DIR/.local/bin/gamescope-launch.sh"

############################################################
# WINEHQ INSTALL
############################################################

if ! command -v wine &>/dev/null; then

run sudo dpkg --add-architecture i386
sudo mkdir -pm755 /etc/apt/keyrings

curl -fsSL https://dl.winehq.org/wine-builds/winehq.key \
 | sudo gpg --dearmor -o /etc/apt/keyrings/winehq.gpg

echo "deb [signed-by=/etc/apt/keyrings/winehq.gpg] https://dl.winehq.org/wine-builds/ubuntu noble main" \
 | sudo tee /etc/apt/sources.list.d/winehq.list

run sudo apt update
apt_install winehq-stable

fi

############################################################
# WINE PREFIX + WINETRICKS
############################################################

if [[ ! -d "$WINEPREFIX" ]]; then
WINEPREFIX="$WINEPREFIX" WINEARCH=win64 wineboot
fi

WINEPREFIX="$WINEPREFIX" winetricks -q corefonts vcrun2019 dxvk

############################################################
# YABRIDGE INSTALL
############################################################

mkdir -p "$YABRIDGE_DIR"

LATEST_URL=$(curl -s https://api.github.com/repos/robbert-vdh/yabridge/releases/latest \
 | jq -r '.assets[] | select(.name|test("linux.*tar.gz")) | .browser_download_url' | head -n1)

if [[ -n "$LATEST_URL" ]]; then
wget -O "$YABRIDGE_DIR/yabridge.tar.gz" "$LATEST_URL"
tar -xzf "$YABRIDGE_DIR/yabridge.tar.gz" -C "$YABRIDGE_DIR"
fi

export PATH="$YABRIDGE_DIR:$PATH"

if command -v yabridgectl &>/dev/null; then
mkdir -p "$HOME_DIR/.vst" "$HOME_DIR/.vst3"
yabridgectl set --wine-prefix="$WINEPREFIX"
yabridgectl sync
fi

############################################################
# BITWIG AUTO INSTALL
############################################################

BITWIG_DEB=$(ls -t "$HOME_DIR"/Downloads/Bitwig_Studio_*.deb 2>/dev/null | head -n1 || true)

if [[ -n "$BITWIG_DEB" ]]; then
run sudo dpkg -i "$BITWIG_DEB" || true
run sudo apt -f install -y
fi

############################################################
# PROFILE SWITCHER TRAY
############################################################

mkdir -p "$HOME_DIR/bin"

cat > "$HOME_DIR/bin/profile-switcher.py" <<'EOF'
#!/usr/bin/env python3
import subprocess, sys
from PyQt6.QtWidgets import QApplication, QSystemTrayIcon, QMenu
from PyQt6.QtGui import QIcon

HOME = subprocess.getoutput("echo $HOME")

def run(cmd): subprocess.Popen(cmd, shell=True)

app = QApplication(sys.argv)
tray = QSystemTrayIcon(QIcon.fromTheme("audio-card"))
tray.setVisible(True)

menu = QMenu()
menu.addAction("Studio Mode").triggered.connect(lambda: run(f"{HOME}/.local/bin/studio-mode.sh"))
menu.addAction("Game Mode").triggered.connect(lambda: run(f"{HOME}/.local/bin/performance-mode.sh"))
menu.addAction("VST Sync").triggered.connect(lambda: run("yabridgectl sync"))

tray.setContextMenu(menu)
sys.exit(app.exec())
EOF

chmod +x "$HOME_DIR/bin/profile-switcher.py"

mkdir -p "$HOME_DIR/.config/autostart"

cat > "$HOME_DIR/.config/autostart/profile-switcher.desktop" <<EOF
[Desktop Entry]
Type=Application
Exec=$HOME_DIR/bin/profile-switcher.py
Name=Audio/Game Profile Switcher
EOF

############################################################
# DONE
############################################################

log "Setup Complete!"
log "Reboot recommended."
