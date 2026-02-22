#!/usr/bin/env bash
# setup-laptop-remote.sh — Bootstrap laptop for remote access to home M1 Max
# Run this ON THE LAPTOP (EndeavourOS, 2018 Mac i5)
set -euo pipefail

HOME_TAILSCALE_IP="100.117.232.15"
HOME_HOSTNAME="home"

echo "=== Laptop Remote Access Setup ==="
echo "Home machine Tailscale IP: $HOME_TAILSCALE_IP"
echo ""

# ── Step 1: Install packages ──────────────────────────────────────
echo "[1/8] Installing packages..."
sudo pacman -S --needed --noconfirm \
    tailscale openssh mosh tmux tigervnc \
    starship zoxide fzf bat ripgrep fd

# Ghostty — check if already installed (AUR)
if ! command -v ghostty &>/dev/null; then
    echo "  → Ghostty not found. Install from AUR: yay -S ghostty"
fi

# ── Step 2: Enable Tailscale ──────────────────────────────────────
echo "[2/8] Enabling Tailscale..."
sudo systemctl enable --now tailscaled
if ! tailscale status &>/dev/null; then
    echo "  → Tailscale not connected. Authenticating..."
    sudo tailscale up
fi
echo "  → Tailscale IP: $(tailscale ip -4 2>/dev/null || echo 'pending')"

# ── Step 3: Generate SSH keypair ──────────────────────────────────
echo "[3/8] Setting up SSH..."
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    ssh-keygen -t ed25519 -C "juansbiz@laptop" -f "$HOME/.ssh/id_ed25519" -N ""
    echo "  → Keypair generated."
else
    echo "  → SSH keypair already exists."
fi

# ── Step 4: Copy key to home machine ─────────────────────────────
echo "[4/8] Copying SSH key to home machine..."
echo "  → You'll be prompted for your home machine password (juansbiz user)."
echo "  → This is a one-time step — after this, pubkey auth takes over."
echo ""
if ssh-copy-id -i "$HOME/.ssh/id_ed25519.pub" "juansbiz@$HOME_TAILSCALE_IP"; then
    echo "  → Key copied successfully!"

    # ── Step 5: Lock down home machine — disable password auth ────
    echo "[5/8] Hardening home SSH — disabling password auth..."
    ssh "juansbiz@$HOME_TAILSCALE_IP" \
        "sudo sed -i 's/^PasswordAuthentication yes.*/PasswordAuthentication no/' /etc/ssh/sshd_config.d/99-hardened.conf && sudo systemctl reload sshd && echo '  → Password auth disabled. Pubkey only from now on.'"
else
    echo "  !! ssh-copy-id failed. Make sure:"
    echo "     1. Tailscale is connected (tailscale status)"
    echo "     2. Home machine is on (ping $HOME_TAILSCALE_IP)"
    echo "     3. You know the juansbiz password"
    echo "  Re-run this script after fixing."
    exit 1
fi

# ── Step 6: SSH config ────────────────────────────────────────────
echo "[6/8] Writing SSH config..."
cat > "$HOME/.ssh/config" << SSHEOF
# Home M1 Max — full remote development
Host home
    HostName $HOME_TAILSCALE_IP
    User juansbiz
    IdentityFile ~/.ssh/id_ed25519
    # Port forwarding for dev servers
    LocalForward 3000 127.0.0.1:3000
    LocalForward 3002 127.0.0.1:3002
    LocalForward 3005 127.0.0.1:3005
    LocalForward 3006 127.0.0.1:3006
    LocalForward 7100 127.0.0.1:7100
    LocalForward 18789 127.0.0.1:18789
    LocalForward 18790 127.0.0.1:18790
    LocalForward 18791 127.0.0.1:18791
    LocalForward 8384 127.0.0.1:8384
    # Multiplexing — reuse connections
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600
    # Keepalive
    ServerAliveInterval 30
    ServerAliveCountMax 120
    # Compression for low bandwidth
    Compression yes
    # Forward agent for git
    ForwardAgent yes

# Home M1 Max — terminal only, no port forwarding
Host home-lite
    HostName $HOME_TAILSCALE_IP
    User juansbiz
    IdentityFile ~/.ssh/id_ed25519
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 600
    ServerAliveInterval 30
    ServerAliveCountMax 120
    Compression yes
    ForwardAgent yes
SSHEOF
chmod 600 "$HOME/.ssh/config"
mkdir -p "$HOME/.ssh/sockets"
echo "  → SSH config written (hosts: 'home', 'home-lite')"

# ── Step 7: Connection scripts ────────────────────────────────────
echo "[7/8] Creating connection scripts..."
mkdir -p "$HOME/.local/bin"

# remote-code — SSH + tmux
cat > "$HOME/.local/bin/remote-code" << 'RCEOF'
#!/usr/bin/env bash
# remote-code — Connect to home machine coding session
set -euo pipefail

HOST="home-lite"
SESSION="coding"

usage() {
    echo "Usage: remote-code [--ports] [--mosh]"
    echo "  --ports   Use full port forwarding (dev servers accessible on localhost)"
    echo "  --mosh    Use mosh instead of SSH (better for unstable connections)"
    exit 0
}

USE_PORTS=false
USE_MOSH=false

for arg in "$@"; do
    case $arg in
        --ports) USE_PORTS=true; HOST="home" ;;
        --mosh)  USE_MOSH=true ;;
        --help)  usage ;;
    esac
done

if $USE_MOSH; then
    echo "Connecting via mosh..."
    mosh juansbiz@100.117.232.15 -- tmux new-session -A -s "$SESSION"
else
    echo "Connecting via SSH to $HOST..."
    ssh -t "$HOST" "tmux new-session -A -s $SESSION"
fi
RCEOF
chmod +x "$HOME/.local/bin/remote-code"

# remote-desktop — VNC to Hyprland desktop
cat > "$HOME/.local/bin/remote-desktop" << 'RDEOF'
#!/usr/bin/env bash
# remote-desktop — Connect to home machine's Hyprland desktop via VNC
set -euo pipefail

HOME_IP="100.117.232.15"
VNC_PORT="5910"

echo "Connecting to Hyprland desktop at $HOME_IP:$VNC_PORT..."
echo "Tip: Super+Escape toggles passthrough mode (local shortcuts on/off)"
echo ""

vncviewer "$HOME_IP::$VNC_PORT" \
    -QualityLevel=8 \
    -CompressLevel=2 \
    -PreferredEncoding=Tight \
    -FullScreen=0 \
    -RemoteResize=1 \
    -Shared=1 2>/dev/null &

disown
echo "VNC viewer launched in background."
RDEOF
chmod +x "$HOME/.local/bin/remote-desktop"

# remote-disconnect — Close all connections
cat > "$HOME/.local/bin/remote-disconnect" << 'DDEOF'
#!/usr/bin/env bash
# remote-disconnect — Close all remote connections to home machine
echo "Closing SSH multiplexed connections..."
ssh -O exit home 2>/dev/null && echo "  → home closed" || echo "  → home: no connection"
ssh -O exit home-lite 2>/dev/null && echo "  → home-lite closed" || echo "  → home-lite: no connection"

echo "Killing VNC viewers..."
pkill -f vncviewer 2>/dev/null && echo "  → VNC viewers killed" || echo "  → No VNC viewers running"

echo "Done."
DDEOF
chmod +x "$HOME/.local/bin/remote-disconnect"

echo "  → Created: remote-code, remote-desktop, remote-disconnect"

# ── Step 8: VS Code Remote SSH ────────────────────────────────────
echo "[8/8] VS Code Remote SSH..."
if command -v code &>/dev/null; then
    code --install-extension ms-vscode-remote.remote-ssh 2>/dev/null || true
    echo "  → Extension installed."
else
    echo "  → VS Code not found. Install it, then run:"
    echo "    code --install-extension ms-vscode-remote.remote-ssh"
fi

# ── Hyprland host.conf reminder ───────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/laptop-host.conf" ]; then
    mkdir -p "$HOME/.config/hypr"
    cp "$SCRIPT_DIR/laptop-host.conf" "$HOME/.config/hypr/host.conf"
    echo ""
    echo "  → Copied laptop-host.conf → ~/.config/hypr/host.conf"

    # Add source line to hyprland.conf if not already present
    HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
    if [ -f "$HYPR_CONF" ] && ! grep -q 'source.*host\.conf' "$HYPR_CONF"; then
        # Add after the last existing source line
        sed -i '/^source = /a source = ~/.config/hypr/host.conf' "$HYPR_CONF"
        echo "  → Added 'source = ~/.config/hypr/host.conf' to hyprland.conf"
    fi
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                    SETUP COMPLETE                              ║"
echo "╠══════════════════════════════════════════════════════════════════╣"
echo "║                                                                ║"
echo "║  Quick reference:                                              ║"
echo "║                                                                ║"
echo "║  remote-code              SSH + tmux (terminal coding)         ║"
echo "║  remote-code --ports      + port forwarding (dev servers)      ║"
echo "║  remote-code --mosh       Mosh (unstable WiFi)                 ║"
echo "║  remote-desktop           VNC to Hyprland desktop              ║"
echo "║  remote-disconnect        Close all connections                ║"
echo "║                                                                ║"
echo "║  VS Code:                                                     ║"
echo "║  code --remote ssh-remote+home /home/juansbiz/Desktop/CODE    ║"
echo "║                                                                ║"
echo "║  VNC credentials:                                              ║"
echo "║  Username: juansbiz    (you know the password)                 ║"
echo "║                                                                ║"
echo "║  Super+Escape = toggle passthrough (for remote desktop)        ║"
echo "║                                                                ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
