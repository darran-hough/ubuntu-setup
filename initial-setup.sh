#!/usr/bin/env bash
# ==========================================================
# Ubuntu Studio / Gaming Dual Environment
# Ubuntu 24.04 LTS
# v2.1 – FULL CONSOLIDATED SCRIPT
# ==========================================================

set -euo pipefail

echo "🚀 Ubuntu Studio / Gaming setup starting..."

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
  steam \
  gamemode \
  yad \
  gdebi-core \
  gnome-tweaks

# ----------------------------------------------------------
# Ubuntu low-latency kernel (OFFICIAL)
# ----------------------------------------------------------
if ! dpkg -l | grep -q linux-lowlatency; then
  echo "🧠 Installing Ubuntu low-latency kernel..."
  sudo apt install -y linux-lowlatency
else
  echo "✅ Low-latency kernel already installed"
fi

# ----------------------------------------------------------
# Bitwig (from ~/Downloads)
# ----------------------------------------------------------
BITWIG_DEB="$HOME/Downloads/BitwigStudio.deb"
if [[ -f "$BITWIG_DEB" ]]; then
  sudo gdebi -n "$BITWIG_DEB"
else
  echo "⚠️ BitwigStudio.deb not found – skipping"
fi

# ----------------------------------------------------------
# Real-time audio limits
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
# YaBridge (NO MAKE STEP – FIXES YOUR ERROR)
# ----------------------------------------------------------
if ! command -v yabridgectl >/dev/null; then
  echo "🔧 Installing yabridge..."
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
# Mode scripts
# ----------------------------------------------------------
mkdir -p ~/modes

# =======================
# STUDIO MODE
# =======================
cat > ~/modes/studio-mode.sh <<'EOF'
#!/usr/bin/env bash
echo "studio" > ~/.current_mode

# CPU governor (portable)
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo performance | sudo tee "$gov" >/dev/null || true
done

sudo systemctl stop bluetooth cups 2>/dev/null || true
echo -1 | sudo tee /sys/module/usbcore/parameters/autosuspend >/dev/null

systemctl --user restart pipewire pipewire-pulse wireplumber

yad --notification --text="🎹 Studio Mode active"
EOF
chmod +x ~/modes/studio-mode.sh

# =======================
# GAME MODE
# =======================
cat > ~/modes/game-mode.sh <<'EOF'
#!/usr/bin/env bash
echo "game" > ~/.current_mode

sudo systemctl start bluetooth cups 2>/dev/null || true

for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
  echo performance | sudo tee "$gov" >/dev/null || true
done

echo 2 | sudo tee /sys/module/usbcore/parameters/autosuspend >/dev/null

if command -v nvidia-smi >/dev/null; then
  sudo nvidia-smi -pm 1
fi

yad --notification --text="🎮 Game Mode active"
EOF
chmod +x ~/modes/game-mode.sh

# =======================
# MODE SWITCHER (Tray)
# =======================
cat > ~/modes/mode-switcher.sh <<'EOF'
#!/usr/bin/env bash
while true; do
  CHOICE=$(yad --list --column=Mode \
    "Studio Mode" \
    "Game Mode" \
    "VST Sync" \
    --width=300 --height=200 \
    --title="Mode Switcher" \
    --button=gtk-cancel:1)

  case "$CHOICE" in
    "Studio Mode") ~/modes/studio-mode.sh ;;
    "Game Mode")   ~/modes/game-mode.sh ;;
    "VST Sync")    yabridgectl sync && yad --info --text="VST Sync complete" ;;
    *) exit 0 ;;
  esac
done
EOF
chmod +x ~/modes/mode-switcher.sh

# ----------------------------------------------------------
# Autostart tray
# ----------------------------------------------------------
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/mode-switcher.desktop <<EOF
[Desktop Entry]
Type=Application
Exec=$HOME/modes/mode-switcher.sh
Name=Mode Switcher
X-GNOME-Autostart-enabled=true
EOF

echo "✅ Setup complete."
echo "🔁 REBOOT REQUIRED to boot low-latency kernel"
