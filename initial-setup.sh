#!/bin/bash
set -e

########################################
# Unified Studio/Game Mode Switcher
# Auto-installs everything, no prompts
########################################

USER_NAME=$(whoami)
HOME_DIR="$HOME"
SCRIPT_DIR="$HOME_DIR"

MODE_SWITCHER="$SCRIPT_DIR/mode-switcher.sh"
TRAY_APP="$SCRIPT_DIR/mode-tray.py"
AUTOSTART_DIR="$HOME_DIR/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/mode-tray.desktop"

YABRIDGE_VERSION="5.1.0"
YABRIDGE_URL="https://github.com/robbert-vdh/yabridge/releases/download/${YABRIDGE_VERSION}/yabridge-${YABRIDGE_VERSION}.tar.gz"
YABRIDGE_BIN="$HOME_DIR/.local/share/yabridge/yabridgectl"

########################################
# Helpers
########################################
function require_sudo() {
  if ! command -v sudo >/dev/null; then
    echo "❌ sudo is required."
    exit 1
  fi
}

function ensure_dir() {
  mkdir -p "$1"
}

########################################
# Mode Switcher script
########################################
function write_mode_switcher() {
cat > "$MODE_SWITCHER" <<'EOF'
#!/bin/bash
set -e

MODE="$1"

if [[ "$MODE" != "audio" && "$MODE" != "gaming" ]]; then
  echo "Usage: $0 [audio|gaming]"
  exit 1
fi

AUDIO_LIMITS_FILE="/etc/security/limits.d/audio.conf"

if [[ "$MODE" == "audio" ]]; then
  echo "🎧 Switching to AUDIO mode..."
  sudo tee "$AUDIO_LIMITS_FILE" >/dev/null <<EOF2
@audio   -  rtprio     95
@audio   -  memlock    unlimited
@audio   -  nice      -19
EOF2

  echo "🔧 Enabling TLP..."
  sudo systemctl enable tlp || true
  sudo systemctl restart tlp || true

  echo "✅ AUDIO mode enabled."
  exit 0
fi

if [[ "$MODE" == "gaming" ]]; then
  echo "🎮 Switching to GAMING mode..."
  sudo rm -f "$AUDIO_LIMITS_FILE"

  echo "🔧 Disabling TLP..."
  sudo systemctl stop tlp || true
  sudo systemctl disable tlp || true

  echo "✅ GAMING mode enabled."
  exit 0
fi
EOF

chmod +x "$MODE_SWITCHER"
}

########################################
# Tray app
########################################
function write_tray_app() {
cat > "$TRAY_APP" <<'EOF'
#!/usr/bin/env python3

import os
import sys
import subprocess
from pathlib import Path
from PyQt6 import QtWidgets, QtGui

HOME = str(Path.home())
MODE_SWITCHER = os.path.join(HOME, "mode-switcher.sh")
YABRIDGECTL = os.path.join(HOME, ".local/share/yabridge/yabridgectl")

def run_cmd(cmd):
    return subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

def set_mode(mode):
    if mode not in ["audio", "gaming"]:
        return False
    run_cmd(f"bash {MODE_SWITCHER} {mode}")
    return True

def sync_vst():
    run_cmd(f"{YABRIDGECTL} sync")

def get_current_mode():
    limits_file = "/etc/security/limits.d/audio.conf"
    return "audio" if os.path.exists(limits_file) else "gaming"

class TrayApp(QtWidgets.QSystemTrayIcon):
    def __init__(self):
        super().__init__()

        self.menu = QtWidgets.QMenu()

        studio_menu = QtWidgets.QMenu("Studio", self.menu)
        studio_mode_action = studio_menu.addAction("Enable Studio Mode")
        vst_sync_action = studio_menu.addAction("VST Sync")

        self.menu.addMenu(studio_menu)
        self.menu.addSeparator()
        game_mode_action = self.menu.addAction("Enable Game Mode")
        self.menu.addSeparator()
        quit_action = self.menu.addAction("Quit")

        studio_mode_action.triggered.connect(self.enable_studio)
        vst_sync_action.triggered.connect(self.vst_sync)
        game_mode_action.triggered.connect(self.enable_game)
        quit_action.triggered.connect(QtWidgets.QApplication.quit)

        self.setContextMenu(self.menu)

        # Use default icons
        self.audio_icon = QtGui.QIcon.fromTheme("media-playback-start")
        self.game_icon = QtGui.QIcon.fromTheme("applications-games")

        self.update_icon()

    def update_icon(self):
        mode = get_current_mode()
        if mode == "audio":
            self.setIcon(self.audio_icon)
            self.setToolTip("Studio Mode")
        else:
            self.setIcon(self.game_icon)
            self.setToolTip("Game Mode")

    def enable_studio(self):
        set_mode("audio")
        self.update_icon()

    def vst_sync(self):
        sync_vst()
        self.update_icon()

    def enable_game(self):
        set_mode("gaming")
        self.update_icon()

def main():
    app = QtWidgets.QApplication(sys.argv)
    tray = TrayApp()
    tray.show()
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
EOF

chmod +x "$TRAY_APP"
}

########################################
# Autostart file
########################################
function write_autostart() {
  ensure_dir "$AUTOSTART_DIR"

cat > "$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Studio/Game Mode Switcher
Exec=/usr/bin/python3 $TRAY_APP
X-GNOME-Autostart-enabled=true
EOF
}

########################################
# Install everything (run once)
########################################
function install_all() {
  require_sudo

  echo "🔄 Updating system..."
  sudo apt update
  sudo apt upgrade -y
  sudo apt autoremove -y
  sudo apt clean

  echo "🧠 Installing low-latency kernel..."
  sudo apt install -y linux-lowlatency

  echo "⚡ Installing CPU tools..."
  sudo apt install -y cpufrequtils tlp

  echo "🎚️ Installing PipeWire audio tools..."
  sudo apt install -y pipewire-jack qpwgraph pavucontrol

  echo "🍷 Installing Wine..."
  sudo dpkg --add-architecture i386
  sudo apt update
  sudo apt install -y wine64 wine32 winetricks

  echo "🧰 Installing Python tray dependencies..."
  sudo apt install -y python3-pyqt6

  echo "🔌 Installing yabridge..."
  mkdir -p "$HOME_DIR/.local/share"
  mkdir -p "$HOME_DIR/.local/bin"
  cd /tmp
  wget -q "$YABRIDGE_URL" -O yabridge.tar.gz
  tar -xzf yabridge.tar.gz
  rm -rf "$HOME_DIR/.local/share/yabridge"
  mv yabridge "$HOME_DIR/.local/share/yabridge"
  ln -sf "$HOME_DIR/.local/share/yabridge/yabridgectl" "$HOME_DIR/.local/bin/yabridgectl"

  if ! echo "$PATH" | grep -q "$HOME_DIR/.local/bin"; then
    echo 'export PATH="$HOME_DIR/.local/bin:$PATH"' >> "$HOME_DIR/.profile"
  fi

  export WINEPREFIX="$HOME_DIR/.wine-audio"
  export WINEARCH=win64
  wineboot -u

  write_mode_switcher
  write_tray_app
  write_autostart

  bash "$MODE_SWITCHER" gaming

  echo
  echo "✅ Install complete!"
  echo "🔁 Please reboot once."
  echo "🎮 Game mode is set as default."
}

########################################
# Main
########################################
install_all
