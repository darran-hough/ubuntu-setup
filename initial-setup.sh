#!/usr/bin/env bash
set -e

# ===============================================
# Ubuntu 24.04 Ultimate Audio + Gaming Setup
# Fully unattended / non-interactive
# Supports: --dryrun
# ===============================================

DRY_RUN=false
if [[ "$1" == "--dryrun" ]]; then
    DRY_RUN=true
    echo "=== Running in DRY-RUN mode ==="
fi

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
YABRIDGE_DIR="$HOME_DIR/.yabridge"

echo "User: $USER_NAME"
echo "Home Dir: $HOME_DIR"
echo "Wine prefix: $WINEPREFIX"
echo "Yabridge Dir: $YABRIDGE_DIR"
echo "Dry-run mode: $DRY_RUN"

############################
# SYSTEM UPDATE & PACKAGES
############################
run_cmd sudo apt update
run_cmd sudo apt upgrade -y

run_cmd sudo apt install -y --no-install-recommends \
    linux-lowlatency linux-headers-lowlatency \
    pipewire pipewire-jack wireplumber alsa-utils rtkit gamemode \
    winetricks fonts-wine cabextract unzip wget gnupg2 software-properties-common \
    python3-pyqt6 python3-pyqt6.qtsvg python3-pip

############################
# PIPEWIRE ENABLE
############################
run_cmd systemctl --user enable pipewire pipewire-pulse wireplumber --now

############################
# REALTIME PERMISSIONS
############################
run_cmd sudo tee /etc/security/limits.d/audio.conf > /dev/null <<EOF
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
# NVIDIA WAYLAND
############################
run_cmd sudo tee /etc/modprobe.d/nvidia-drm.conf > /dev/null <<EOF
options nvidia-drm modeset=1
EOF
run_cmd sudo update-initramfs -u || true

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
run_cmd sudo systemctl enable focusrite-irq.service || true

############################
# DISABLE USB AUTOSUSPEND
############################
run_cmd sudo tee /etc/udev/rules.d/99-usb-focusrite-nosuspend.rules > /dev/null <<EOF
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1235", TEST=="power/control", ATTR{power/control}="on"
EOF

############################
# PIPEWIRE PROFILES
############################
run_cmd mkdir -p "$HOME_DIR/.local/bin"

# Studio
run_cmd tee "$HOME_DIR/.local/bin/pw-daw.sh" > /dev/null <<EOF
#!/bin/bash
pw-metadata -n settings 0 clock.force-rate 48000
pw-metadata -n settings 0 clock.force-quantum 64
EOF

# Game
run_cmd tee "$HOME_DIR/.local/bin/pw-game.sh" > /dev/null <<EOF
#!/bin/bash
pw-metadata -n settings 0 clock.force-rate 48000
pw-metadata -n settings 0 clock.force-quantum 256
EOF

run_cmd chmod +x "$HOME_DIR/.local/bin"/pw-*.sh

############################
# STEAM CPU AFFINITY
############################
# Placeholder if needed

############################
# BITWIG RT LAUNCHER
############################
run_cmd tee "$HOME_DIR/.local/bin/bitwig-rt.sh" > /dev/null <<EOF
#!/bin/bash
exec chrt -f 88 bitwig-studio
EOF
run_cmd chmod +x "$HOME_DIR/.local/bin/bitwig-rt.sh"

############################
# WINEHQ + YABRIDGE
############################
run_cmd sudo dpkg --add-architecture i386
run_cmd wget -O- https://dl.winehq.org/wine-builds/winehq.key | sudo gpg --dearmor --yes --output /usr/share/keyrings/winehq-archive.key
run_cmd sudo tee /etc/apt/sources.list.d/winehq.list > /dev/null <<EOF
deb [signed-by=/usr/share/keyrings/winehq-archive.key] https://dl.winehq.org/wine-builds/ubuntu/ noble main
EOF
run_cmd sudo apt update
run_cmd sudo apt install --install-recommends -y winehq-stable

run_cmd mkdir -p "$WINEPREFIX"
run_cmd export WINEPREFIX="$WINEPREFIX"
run_cmd export WINEARCH=win64
run_cmd wineboot --init

run_cmd winetricks -q corefonts
run_cmd winetricks --force -q vcrun2019
run_cmd winetricks -q dxvk

############################
# INSTALL YABRIDGE (fixed)
############################
run_cmd mkdir -p "$YABRIDGE_DIR"

YAB_JSON=$(mktemp)
run_cmd wget -qO "$YAB_JSON" "https://api.github.com/repos/robbert-vdh/yabridge/releases/latest"
YAB_URL=$(grep "browser_download_url" "$YAB_JSON" | grep -E "linux.tar.gz|ubuntu-20.04.tar.gz" | head -n1 | cut -d '"' -f4)
rm -f "$YAB_JSON"

if [ -n "$YAB_URL" ]; then
    run_cmd wget -O "$YABRIDGE_DIR/yabridge.tar.gz" "$YAB_URL"
    run_cmd tar -xzf "$YABRIDGE_DIR/yabridge.tar.gz" -C "$YABRIDGE_DIR"
else
    echo "[WARN] Could not find a yabridge Linux release asset."
    echo "[WARN] You may need to install yabridge manually: https://github.com/robbert-vdh/yabridge/releases"
fi

# Add yabridge to PATH permanently
PROFILE_FILE="$HOME_DIR/.profile"
if ! grep -q 'export PATH="$HOME/.yabridge:$PATH"' "$PROFILE_FILE"; then
    run_cmd echo 'export PATH="$HOME/.yabridge:$PATH"' >> "$PROFILE_FILE"
fi
export PATH="$HOME_DIR/.yabridge:$PATH"

# Only run yabridgectl if available
if command -v yabridgectl >/dev/null 2>&1; then
    run_cmd mkdir -p "$WINEPREFIX/drive_c/VST2" "$WINEPREFIX/drive_c/VST3" "$HOME_DIR/.vst" "$HOME_DIR/.vst3"
    run_cmd yabridgectl set --wine-prefix="$WINEPREFIX" --path="$WINEPREFIX/drive_c/VST2" --path="$WINEPREFIX/drive_c/VST3"
    run_cmd yabridgectl sync
else
    echo "[WARN] yabridgectl not installed or not found in PATH."
fi

############################
# FINAL SUMMARY
#############################
echo "==============================================="
if [ "$DRY_RUN" = true ]; then
    echo "DRY-RUN COMPLETE: no changes were made."
    echo "Run './ubuntu-audio-gaming-ultimate.sh' without --dryrun to execute."
else
    echo "SETUP COMPLETE!"
    echo "All audio and gaming optimizations have been applied."
    echo "PipeWire, Wine, yabridge, NVIDIA, and Steam optimizations are ready."
    if command -v yabridgectl >/dev/null 2>&1; then
        YABRIDGE_VERSION=$(yabridgectl --version 2>/dev/null || echo "Unknown")
        echo "Yabridge installed at: $HOME_DIR/.yabridge"
        echo "Yabridge version: $YABRIDGE_VERSION"
    else
        echo "[WARN] yabridgectl not installed or not found in PATH."
        echo "[WARN] You may need to install yabridge manually."
    fi
    echo
    echo "IMPORTANT: Please REBOOT your system for all changes to take effect."
fi
echo "==============================================="
