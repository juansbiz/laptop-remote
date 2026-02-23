#!/usr/bin/env bash
# remote-desktop — Connect to home machine's Hyprland desktop via VNC
set -euo pipefail

HOME_IP="100.117.232.15"
VNC_PORT="5910"

echo "Connecting to Hyprland desktop at $HOME_IP:$VNC_PORT..."
echo "Tip: Super+Escape toggles passthrough mode"
echo ""

# Use TigerVNC with optimal compression and lower quality for speed
# Window fits laptop screen without scrollbars
vncviewer "$HOME_IP::$VNC_PORT" \
    -geometry 2560x1600 \
    -QualityLevel=2 \
    -CompressLevel=9 \
    -PreferredEncoding=ZRLE \
    -Fullscreen=0 \
    -Shared=1 2>/dev/null &

disown
echo "VNC viewer launched."
