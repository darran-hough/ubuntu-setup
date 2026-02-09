#!/usr/bin/env bash
set -e

# ================================
# Ubuntu Ultimate Audio + Gaming Setup
# Supports: --dryrun
# ================================

# Default
DRY_RUN=false

# Parse command-line argument
if [[ "$1" == "--dryrun" ]]; then
    DRY_RUN=true
    echo "=== Running in DRY-RUN mode ==="
fi

# Helper function to conditionally run commands
run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] $*"
    else
        eval "$@"
    fi
}

USER_NAME=$(whoami)
HOME_DIR="/home/$USER_NAME"
WINEPREFIX="$HOME_DIR/.wine-yabridge"

echo "User: $USER_NAME"
echo "Home Dir: $HOME_DIR"
echo "Wine prefix: $WINEPREFIX"
echo "Dry-run mode: $DRY_RUN"

############################
# SYSTEM UPDATE & PACKAGES
############################
run_cmd sudo apt update
run_cmd sudo apt upgrade -y

run_cmd sudo apt install -y \
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
run_cmd systemctl --user enable pipewire pipewire-pulse wireplumber --now

############################
# REALTIME PERMISSIONS
############################
run_cmd tee /etc/security/limits.d/audio.conf > /dev/null <<EOF
@audio   -  rtprio     95
@audio   -  memlock    unlimited
@audio   -  nice      -19
EOF

run_cmd sudo usermod -aG audio "$USER_NAME"

############################
# PIPEWIRE LOW LATENCY
############################
run_cmd mkdir -p "$HOME_DIR/.config/wireplumber/wireplumber.conf.d"
run_cmd tee "$HOME_DIR/.config/wireplumber/wireplumber.conf.d/99-low-latency.conf" > /dev/null <<EOF
context.properties = {
    default.clock.rate        = 48000
    default.clock.quantum     = 64
    default.clock.min-quantum = 32
    default.clock.max-quantum = 256
}
EOF

run_cmd mkdir -p "$HOME_DIR/.config/pipewire/pipewire.conf.d"
run_cmd tee "$HOME_DIR/.config/pipewire/pipewire.conf.d/99-rt.conf" > /dev/null <<EOF
context.properties = {
    realtime.priority = 88
}
EOF

############################
# CPU ISOLATION (2–3 AUDIO)
############################
run_cmd sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash isolcpus=2,3 nohz_full=2,3 rcu_nocbs=2,3 threadirqs"/' /etc/default/grub
run_cmd sudo update-grub

############################
# NVIDIA WAYLAND
############################
run_cmd sudo tee /etc/modprobe.d/nvidia-drm.conf > /dev/null <<EOF
options nvidia-drm modeset=1
EOF
run_cmd sudo update-initramfs -u

run_cmd sudo tee /etc/systemd/system/nvidia-rt.service > /dev/null <<EOF
[Unit]
Description=NVIDIA RT Performance Mode
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/nvidia-smi -pm 1

[Install]
WantedBy=multi-user.target
EOF

run_cmd sudo systemctl enable nvidia-rt.service

############################
# FOCUSRITE IRQ PINNING
############################
run_cmd sudo tee /usr/local/bin/focusrite-irq.sh > /dev/null <<EOF
#!/bin/bash
MASK=0c
for IRQ in \$(grep -i snd_usb_audio /proc/interrupts | awk '{print \$1}' | tr -d ':'); do
    echo \$MASK > /proc/irq/\$IRQ/smp_affinity
done
EOF

run_cmd sudo chmod +x /usr/local/bin/focusrite-irq.sh

run_cmd sudo tee /etc/systemd/system/focusrite-irq.service > /dev/null <<EOF
[Unit]
Description=Pin Focusrite USB IRQs
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/focusrite-irq.sh

[Install]
WantedBy=multi-user.target
EOF

run_cmd sudo systemctl enable focusrite-irq.service

############################
# DISABLE USB AUTOSUSPEND
############################
run_cmd sudo tee /etc/udev/rules.d/99-usb-focusrite-nosuspend.rules > /dev/null <<EOF
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1235", TEST=="power/control", ATTR{power/control}="on"
EOF

############################
# PIPEWIRE AUTO QUANTUM
############################
run_cmd mkdir -p "$HOME_DIR/.local/bin"

run_cmd tee "$HOME_DIR/.local/bin/pw-daw.sh" > /dev/null <<EOF
#!/bin/bash
pw-metadata -n settings 0 clock.force-rate 48000
pw-metadata -n settings 0 clock.force-quantum 64
EOF

run_cmd tee "$HOME_DIR/.local/bin/pw-game.sh" > /dev/null <<EOF
#!/bin/bash
pw-metadata -n settings 0 clock.force-rate 48000
pw-metadata -n settings 0 clock.force-quantum 256
EOF

run_cmd tee "$HOME_DIR/.local/bin/pw-auto.sh" > /dev/null <<EOF
#!/bin/bash
if pgrep -x bitwig-studio; then
    "$HOME_DIR/.local/bin/pw-daw.sh"
else
    "$HOME_DIR/.local/bin/pw-game.sh"
fi
EOF

run_cmd chmod +x "$HOME_DIR/.local/bin"/pw-*.sh

run_cmd mkdir -p "$HOME_DIR/.config/systemd/user"

run_cmd tee "$HOME_DIR/.config/systemd/user/pw-auto.service" > /dev/null <<EOF
[Service]
ExecStart=$HOME_DIR/.local/bin/pw-auto.sh
EOF

run_cmd tee "$HOME_DIR/.config/systemd/user/pw-auto.timer" > /dev/null <<EOF
[Timer]
OnBootSec=10
OnUnitActiveSec=5

[Install]
WantedBy=timers.target
EOF

run_cmd systemctl --user daemon-reexec
run_cmd systemctl --user enable pw-auto.timer

############################
# STEAM CPU AFFINITY
############################
run_cmd tee "$HOME_DIR/.config/systemd/user/steam-affinity.service" > /dev/null <<EOF
[Service]
ExecStart=/usr/bin/taskset -c 0-1,4-15 %h/.steam/steam/ubuntu12_32/steam
Restart=always
EOF

run_cmd systemctl --user enable steam-affinity.service

############################
# BITWIG RT LAUNCHER
############################
run_cmd tee "$HOME_DIR/.local/bin/bitwig-rt.sh" > /dev/null <<EOF
#!/bin/bash
exec taskset -c 2,3 chrt -f 88 bitwig-studio
EOF

run_cmd chmod +x "$HOME_DIR/.local/bin/bitwig-rt.sh"

############################
# WINE + YABRIDGE
############################
run_cmd sudo dpkg --add-architecture i386
run_cmd sudo apt update

run_cmd mkdir -p "$WINEPREFIX"
run_cmd export WINEPREFIX="$WINEPREFIX"
run_cmd export WINEARCH=win64
run_cmd wineboot --init
run_cmd winetricks -q corefonts vcrun2015 vcrun2019 dxvk
run_cmd mkdir -p "$WINEPREFIX/drive_c/VST2"
run_cmd mkdir -p "$WINEPREFIX/drive_c/VST3"
run_cmd mkdir -p "$HOME_DIR/.vst" "$HOME_DIR/.vst3"
run_cmd yabridgectl set \
  --wine-prefix="$WINEPREFIX" \
  --path="$WINEPREFIX/drive_c/VST2" \
  --path="$WINEPREFIX/drive_c/VST3"
run_cmd yabridgectl sync

############################
# WAYLAND LATENCY FIX
############################
run_cmd gsettings set org.gnome.mutter experimental-features "[]"

echo "==============================================="
if [ "$DRY_RUN" = true ]; then
    echo "DRY-RUN COMPLETE: no changes were made."
    echo "Run './ubuntu-audio-gaming-ultimate.sh' without --dryrun to execute."
else
    echo "Setup COMPLETE. REBOOT recommended."
fi
echo "==============================================="
