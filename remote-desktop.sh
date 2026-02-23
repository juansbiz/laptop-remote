#!/usr/bin/env bash
# remote-desktop — Connect to home machine's Hyprland desktop via VNC
set -euo pipefail

HOME_IP="100.117.232.15"
VNC_PORT="5910"

echo "Connecting to Hyprland desktop at $HOME_IP:$VNC_PORT..."
echo "Tip: Super+Escape toggles passthrough mode"
echo ""

remmina -c "VNC://juansbiz@${HOME_IP}:${VNC_PORT}?quality=9&scale=1&viewmode=1" &

disown
echo "VNC viewer launched."
