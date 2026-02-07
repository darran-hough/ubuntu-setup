#!/usr/bin/env bash
# ==========================================================
# Ubuntu 24.04 Studio + Gaming Hybrid Setup
# Bitwig | Steam | Focusrite | YaBridge | NVIDIA
# v2.5 – FULL SCRIPT WITH PERSISTENT TRAY, MUTUALLY EXCLUSIVE MODES
# ==========================================================

set -euo pipefail

echo "🚀 Starting Ubuntu Studio / Gaming setup..."

# ----------------------------------------------------------
# Keep sudo alive
# ----------------------------------------------------------
sudo -v
( while true; do sudo -n true; sleep 60; done ) &
SUDO_PID=$!
trap 'kill $SUDO_PID' EXIT

# ----------------------------------------------------------
# System update
# ----------------------------------------------------------
sudo apt update
sudo apt -y upgrade
sudo apt -y autoremove

# ----------------------------------------------------------
# Base packages
# ----------------------------------------------------------
sudo apt install -y \
  build-essential git curl wget \
  pipewire pipewire-jack pipewire-audio-client-libraries \
  wireplumber \
  jackd2 qjackctl \
  alsa-utils pavucontrol \
  wine winetricks \
  steam gamemode \
  yad gdebi-core \
  gnome-tweaks

# ----------------------------------------------------------
# Ubuntu low-latency kernel
# ----------------------------------------------------------
if ! dpkg -l | grep -q linux-lowlatency; then
  echo "🧠 Installing low-latency kernel..."
  sudo apt install -y linux-lowlatency
else
  echo "✅ Low-latency kernel already installed"
fi

# ----------------------------------------------------------
# Bitwig installation
# ----------------------------------------------------------
BITWIG_DEB="$HOME/Downloads/BitwigStudio.deb"
if [[ -f "$BITWIG_DEB" ]]; then
  sudo gdebi -n "$BITWIG_DEB"
else
  echo "⚠️ BitwigStudio.deb not found – skipping"
fi

# ----------------------------------------------------------
# Real-time audio privileges
# ----------------------------------------------------------
sudo usermod -aG audio,video "$USER"
sudo tee /etc/security/limits.d/99-audio.conf >/dev/null <<EOF
@audio   -  rtprio     95
@audio   -  memlock    unlimited
@audio   -  nice      -19
EOF

# ----------------------------------------------------------
# Focusrite USB priority
# ----------------------------------------------------------
sudo tee /etc/udev/rules.d/90-focusrite.rules >/dev/null <<EOF
SUBSYSTEM=="usb", ATTR{idVendor}=="1235", MODE="0666"
EOF
sudo udevadm control --reload

# ----------------------------------------------------------
# PipeWire low-latency tuning
# ----------------------------------------------------------
mkdir -p ~/.config/pipewire/pipewire.conf.d
cat > ~/.config/pipewire/pipewire.conf.d/99-lowlatency.conf <<EOF
context.properties = {
  default.clock.rate        = 48000
  default.clock.quantum     = 128
  default.clock.min-quantum = 64
  default.clock.max-quantum = 256
}
EOF

# ----------------------------------------------------------
# YaBridge installation
# ----------------------------------------------------------
if ! command -v yabridgectl >/dev/null; then
  echo "🔧 Installing YaBridge..."
  git clone https://github.com/robbert-vdh/yabridge.git /tmp/yabridge
  mkdir -p ~/.local/bin ~/.local/share/yabridge
  cp /tmp/yabridge/yabridge ~/.local/share/yabridge/
  cp /tmp/yabridge/yabridgectl ~/.local/bin/
  chmod +x ~/.local/bin/yabridgectl ~/.local/share/yabridge/yabridge
  rm -rf /tmp/yabridge
fi
export PATH="$HOME/.local/bin:$PATH"
yabridgectl set --path="$HOME/.wine/drive_c/Program Files/Common Files/VST2" || true

# ----------------------------------------------------------
# Modes folder
# ----------------------------------------------------------
mkdir -p ~/modes

# =======================
# STUDIO MODE SCRIPT
# =======================
cat > ~/modes/studio-mode.sh <<'EOF'
#!/usr/bin/env bash
# Activate Studio Mode
echo "studio" > ~/.current_mode

# CPU governor
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo performance | sudo tee "$gov" >/dev/null || true
done

# Stop unnecessary services for studio
sudo systemctl stop bluetooth cups 2>/dev/null || true
echo -1 | sudo tee /sys/module/usbcore/parameters/autosuspend >/dev/null

# Restart PipeWire
systemctl --user restart pipewire pipewire-pulse wireplumber
EOF
chmod +x ~/modes/studio-mode.sh

# =======================
# GAME MODE SCRIPT
# =======================
cat > ~/modes/game-mode.sh <<'EOF'
#!/usr/bin/env bash
# Activate Game Mode
echo "game" > ~/.current_mode

# CPU governor
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo performance | sudo tee "$gov" >/dev/null || true
done

# Restore services
sudo systemctl start bluetooth cups 2>/dev/null || true
echo 2 | sudo tee /sys/module/usbcore/parameters/autosuspend >/dev/null

# NVIDIA persistence mode
if command -v nvidia-smi >/dev/null; then
  sudo nvidia-smi -pm 1
fi
EOF
chmod +x ~/modes/game-mode.sh

# ----------------------------------------------------------
# SYSTEM TRAY SWITCHER SCRIPT (v2.5)
# ----------------------------------------------------------
cat > ~/modes/mode-switcher.sh <<'EOF'
#!/usr/bin/env bash

MODE_FILE="$HOME/.current_mode"
mkdir -p "$HOME"

# Initialize mode file (default Game Mode)
if [[ ! -f "$MODE_FILE" ]]; then
    echo "game" > "$MODE_FILE"
fi

get_icon() {
    mode=$(cat "$MODE_FILE")
    if [[ "$mode" == "studio" ]]; then
        echo "applications-multimedia"
    else
        echo "applications-games"
    fi
}

run_mode() {
    case "$1" in
        studio)
            "$HOME/modes/studio-mode.sh" ;;
        game)
            "$HOME/modes/game-mode.sh" ;;
        vst)
            yabridgectl sync
            yad --notification --text="VST Sync Complete" ;;
    esac
}

# Persistent tray icon
while true; do
    ICON=$(get_icon)
    # The menu triggers on any click
    yad --notification \
        --image="$ICON" \
        --text="Current Mode: $(cat $MODE_FILE)" \
        --menu="🎹 Studio Mode!run_mode studio|🎮 Game Mode!run_mode game|🔄 VST Sync!run_mode vst" \
        --listen | while read _; do
            # No-op inside, handled by the menu
            :
        done
done
EOF
chmod +x ~/modes/mode-switcher.sh

# ----------------------------------------------------------
# Autostart tray icon
# ----------------------------------------------------------
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/mode-switcher.desktop <<EOF
[Desktop Entry]
Type=Application
Exec=$HOME/modes/mode-switcher.sh
Name=Mode Switcher
X-GNOME-Autostart-enabled=true
EOF

echo "✅ v2.5 setup complete."
echo "🔁 REBOOT REQUIRED to boot low-latency kernel and apply permissions"
