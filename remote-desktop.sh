#!/usr/bin/env bash
# remote-desktop — Connect to home machine's Hyprland desktop via VNC
set -euo pipefail

HOME_IP="100.117.232.15"
VNC_PORT="5910"

echo "Connecting to Hyprland desktop at $HOME_IP:$VNC_PORT..."
echo "Tip: Super+Escape toggles passthrough mode"
echo ""

# Use TigerVNC in fullscreen mode - displays entire 4K desktop
# Config file: ~/.vnc/default.vncviewer handles quality/compression settings
# Press F8 to open menu, then use zoom controls or press F to toggle fullscreen
vncviewer -fullscreen "$HOME_IP::$VNC_PORT" 2>/dev/null &

disown
echo "VNC viewer launched."
