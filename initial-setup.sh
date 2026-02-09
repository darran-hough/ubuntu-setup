#!/usr/bin/env bash
set -e

echo "=== Ubuntu Ultimate Audio + Gaming Setup (RT + Wayland) ==="

USER_NAME=$(whoami)
HOME_DIR="/home/$USER_NAME"
WINEPREFIX="$HOME_DIR/.wine-yabridge"

############################
# SYSTEM & RT KERNEL
############################
sudo apt update
sudo apt upgrade -y

sudo apt install -y \
  linux-image-rt \
  linux-headers-rt \
  pipewire \
  pipewire-jack \
  wireplumber \
  alsa-utils \
  rtkit \
  gamemode \
  wine64 \
  wine32 \
  winetricks \
  fonts-wine \
  cabextract \
  unzip

############################
# PIPEWIRE ENABLE
############################
systemctl --user enable pipewire pipewire-pulse wireplumber --now

############################
# REALTIME PERMISSIONS
############################
sudo tee /etc/security/limits.d/audio.conf > /dev/null <<EOF
@audio   -  rtprio     95
@audio   -  memlock    unlimited
@audio   -  nice      -19
EOF

sudo usermod -aG audio "$USER_NAME"

############################
# PIPEWIRE LOW LATENCY
############################
mkdir -p "$HOME_DIR/.config/wireplumber/wireplumber.conf.d"
tee "$HOME_DIR/.config/wireplumber/wireplumber.conf.d/99-low-latency.conf" > /dev/null <<EOF
context.properties = {
    default.clock.rate        = 48000
    default.clock.quantum     = 128
    default.clock.min-quantum = 64
    default.clock.max-quantum = 1024
}
EOF

mkdir -p "$HOME_DIR/.config/pipewire/pipewire.conf.d"
tee "$HOME_DIR/.config/pipewire/pipewire.conf.d/99-rt.conf" > /dev/null <<EOF
context.properties = {
    realtime.priority = 88
}
EOF

############################
# CPU ISOLATION (2–3 AUDIO)
############################
sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash isolcpus=2,3 nohz_full=2,3 rcu_nocbs=2,3 threadirqs"/' /etc/default/grub
sudo update-grub

############################
# NVIDIA WAYLAND
############################
sudo tee /etc/modprobe.d/nvidia-drm.conf > /dev/null <<EOF
options nvidia-drm modeset=1
EOF
sudo update-initramfs -u

sudo tee /etc/systemd/system/nvidia-rt.service > /dev/null <<EOF
[Unit]
Description=NVIDIA RT Performance Mode
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/nvidia-smi -pm 1

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable nvidia-rt.service

############################
# FOCUSRITE IRQ PINNING
############################
sudo tee /usr/local/bin/focusrite-irq.sh > /dev/null <<EOF
#!/bin/bash
MASK=0c
for IRQ in \$(grep -i snd_usb_audio /proc/interrupts | awk '{print \$1}' | tr -d ':'); do
    echo \$MASK > /proc/irq/\$IRQ/smp_affinity
done
EOF

sudo chmod +x /usr/local/bin/focusrite-irq.sh

sudo tee /etc/systemd/system/focusrite-irq.service > /dev/null <<EOF
[Unit]
Description=Pin Focusrite USB IRQs
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/focusrite-irq.sh

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable focusrite-irq.service

############################
# DISABLE USB AUTOSUSPEND
############################
sudo tee /etc/udev/rules.d/99-usb-focusrite-nosuspend.rules > /dev/null <<EOF
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1235", TEST=="power/control", ATTR{power/control}="on"
EOF

############################
# PIPEWIRE AUTO QUANTUM
############################
mkdir -p "$HOME_DIR/.local/bin"

tee "$HOME_DIR/.local/bin/pw-daw.sh" > /dev/null <<EOF
#!/bin/bash
pw-metadata -n settings 0 clock.force-rate 48000
pw-metadata -n settings 0 clock.force-quantum 64
EOF

tee "$HOME_DIR/.local/bin/pw-game.sh" > /dev/null <<EOF
#!/bin/bash
pw-metadata -n settings 0 clock.force-rate 48000
pw-metadata -n settings 0 clock.force-quantum 256
EOF

tee "$HOME_DIR/.local/bin/pw-auto.sh" > /dev/null <<EOF
#!/bin/bash
if pgrep -x bitwig-studio; then
    "$HOME_DIR/.local/bin/pw-daw.sh"
else
    "$HOME_DIR/.local/bin/pw-game.sh"
fi
EOF

chmod +x "$HOME_DIR/.local/bin"/pw-*.sh

mkdir -p "$HOME_DIR/.config/systemd/user"

tee "$HOME_DIR/.config/systemd/user/pw-auto.service" > /dev/null <<EOF
[Service]
ExecStart=$HOME_DIR/.local/bin/pw-auto.sh
EOF

tee "$HOME_DIR/.config/systemd/user/pw-auto.timer" > /dev/null <<EOF
[Timer]
OnBootSec=10
OnUnitActiveSec=5

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reexec
systemctl --user enable pw-auto.timer

############################
# STEAM CPU AFFINITY
############################
tee "$HOME_DIR/.config/systemd/user/steam-affinity.service" > /dev/null <<EOF
[Service]
ExecStart=/usr/bin/taskset -c 0-1,4-15 %h/.steam/steam/ubuntu12_32/steam
Restart=always
EOF

systemctl --user enable steam-affinity.service

############################
# BITWIG RT LAUNCHER
############################
tee "$HOME_DIR/.local/bin/bitwig-rt.sh" > /dev/null <<EOF
#!/bin/bash
exec taskset -c 2,3 chrt -f 88 bitwig-studio
EOF

chmod +x "$HOME_DIR/.local/bin/bitwig-rt.sh"

############################
# WINE + YABRIDGE
############################
sudo dpkg --add-architecture i386
sudo apt update

export WINEPREFIX="$WINEPREFIX"
export WINEARCH=win64

if [ ! -d "$WINEPREFIX" ]; then
  wineboot --init
fi

winetricks -q corefonts vcrun2015 vcrun2019 dxvk

mkdir -p "$WINEPREFIX/drive_c/VST2"
mkdir -p "$WINEPREFIX/drive_c/VST3"
mkdir -p "$HOME_DIR/.vst" "$HOME_DIR/.vst3"

yabridgectl set \
  --wine-prefix="$WINEPREFIX" \
  --path="$WINEPREFIX/drive_c/VST2" \
  --path="$WINEPREFIX/drive_c/VST3"

yabridgectl sync

############################
# WAYLAND LATENCY FIX
############################
gsettings set org.gnome.mutter experimental-features "[]"

echo "==============================================="
echo "ULTIMATE SETUP COMPLETE"
echo ""
echo "REBOOT REQUIRED"
echo ""
echo "Use:"
echo " • Bitwig Studio (RT)"
echo " • Install VSTs with:"
echo "   WINEPREFIX=$WINEPREFIX wine Plugin.exe"
echo " • Run yabridgectl sync after installs"
echo "==============================================="
