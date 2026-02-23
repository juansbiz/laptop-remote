#!/usr/bin/env bash
# remote-desktop — Connect to home machine's Hyprland desktop via VNC
set -euo pipefail

HOME_IP="100.117.232.15"
VNC_PORT="5910"

echo "Connecting to Hyprland desktop at $HOME_IP:$VNC_PORT..."
echo "Tip: Super+Escape toggles passthrough mode (local shortcuts on/off)"
echo ""
echo "Running at 1280x800 (fits laptop screen without scrollbars)"
echo ""

vncviewer "$HOME_IP::$VNC_PORT" \
    -geometry 1280x800 \
    -QualityLevel=2 \
    -CompressLevel=9 \
    -PreferredEncoding=ZRLE \
    -FullScreen=0 \
    -Shared=1 2>/dev/null &

disown
echo "VNC viewer launched in background."
