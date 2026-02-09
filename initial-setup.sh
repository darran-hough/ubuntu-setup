#!/usr/bin/env bash
set -e

echo "=== Final Audio + Gaming Polish (Bitwig Edition) ==="

USER_NAME=$(whoami)
HOME_DIR=/home/$USER_NAME

### 1. Steam CPU affinity (keep off audio cores 2–3)
mkdir -p $HOME_DIR/.config/systemd/user

tee $HOME_DIR/.config/systemd/user/steam-affinity.service > /dev/null <<EOF
[Unit]
Description=Steam CPU Affinity (protect audio cores)

[Service]
ExecStart=/usr/bin/taskset -c 0-1,4-15 %h/.steam/steam/ubuntu12_32/steam
Restart=always
EOF

systemctl --user daemon-reexec
systemctl --user enable steam-affinity.service --now

### 2. Disable USB autosuspend for Focusrite
sudo tee /etc/udev/rules.d/99-usb-focusrite-nosuspend.rules > /dev/null <<EOF
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1235", TEST=="power/control", ATTR{power/control}="on"
EOF

sudo udevadm control --reload-rules
sudo udevadm trigger

### 3. Bitwig realtime launcher (isolated cores)
mkdir -p $HOME_DIR/.local/bin

tee $HOME_DIR/.local/bin/bitwig-rt.sh > /dev/null <<EOF
#!/bin/bash
exec taskset -c 2,3 chrt -f 88 bitwig-studio
EOF

chmod +x $HOME_DIR/.local/bin/bitwig-rt.sh

### 4. Desktop entry for Bitwig RT
mkdir -p $HOME_DIR/.local/share/applications

tee $HOME_DIR/.local/share/applications/bitwig-rt.desktop > /dev/null <<EOF
[Desktop Entry]
Name=Bitwig Studio (RT)
Comment=Bitwig Studio with realtime priority
Exec=$HOME_DIR/.local/bin/bitwig-rt.sh
Icon=bitwig-studio
Terminal=false
Type=Application
Categories=Audio;Music;
EOF

### 5. Nice-to-have: ensure Bitwig triggers DAW buffer mode immediately
# (forces 64 samples on launch)
$HOME_DIR/.local/bin/pw-daw.sh || true

echo "==============================================="
echo "FINAL POLISH COMPLETE"
echo ""
echo "Use:"
echo " • Bitwig Studio (RT) from app launcher"
echo " • Steam automatically stays off audio cores"
echo " • Focusrite never autosuspends"
echo ""
echo "Reboot recommended (USB + systemd changes)"
echo "==============================================="
