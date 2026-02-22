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
echo "[1/6] Installing packages..."
sudo pacman -S --needed --noconfirm \
    tailscale openssh mosh tmux tigervnc \
    starship zoxide fzf bat ripgrep fd

# Ghostty — check if already installed (AUR)
if ! command -v ghostty &>/dev/null; then
    echo "  → Ghostty not found. Install from AUR: yay -S ghostty"
fi

# ── Step 2: Enable Tailscale ──────────────────────────────────────
echo "[2/6] Enabling Tailscale..."
sudo systemctl enable --now tailscaled
echo "  → Run 'sudo tailscale up' to authenticate if not already connected."
echo "  → Verify with: tailscale status"

# ── Step 3: Generate SSH keypair ──────────────────────────────────
echo "[3/6] Setting up SSH..."
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    ssh-keygen -t ed25519 -C "juansbiz@laptop" -f "$HOME/.ssh/id_ed25519" -N ""
    echo "  → Keypair generated."
else
    echo "  → SSH keypair already exists."
fi

echo ""
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║  ADD THIS PUBLIC KEY to home machine's authorized_keys:    ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo ""
cat "$HOME/.ssh/id_ed25519.pub"
echo ""
echo "  On home machine: echo '<key>' >> ~/.ssh/authorized_keys"
echo ""

# ── Step 4: SSH config ────────────────────────────────────────────
echo "[4/6] Writing SSH config..."
mkdir -p "$HOME/.ssh"
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

# ── Step 5: Connection scripts ────────────────────────────────────
echo "[5/6] Creating connection scripts..."
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

# ── Step 6: VS Code Remote SSH ────────────────────────────────────
echo "[6/6] VS Code Remote SSH..."
if command -v code &>/dev/null; then
    code --install-extension ms-vscode-remote.remote-ssh 2>/dev/null || true
    echo "  → Extension installed. Use: code --remote ssh-remote+home /home/juansbiz/Desktop/CODE"
else
    echo "  → VS Code not found. Install it, then run:"
    echo "    code --install-extension ms-vscode-remote.remote-ssh"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Quick reference:"
echo "  remote-code              SSH + tmux (terminal coding)"
echo "  remote-code --ports      SSH + tmux + port forwarding (dev servers)"
echo "  remote-code --mosh       Mosh + tmux (unstable WiFi)"
echo "  remote-desktop           VNC to Hyprland desktop"
echo "  remote-disconnect        Close all connections"
echo "  code --remote ssh-remote+home /home/juansbiz/Desktop/CODE"
echo ""
echo "NEXT STEP: Add your laptop's public key to the home machine:"
echo "  ssh-copy-id -i ~/.ssh/id_ed25519.pub juansbiz@$HOME_TAILSCALE_IP"
echo "  (or manually append to ~/.ssh/authorized_keys on home machine)"
