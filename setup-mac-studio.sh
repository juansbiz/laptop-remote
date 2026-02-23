#!/usr/bin/env bash
# setup-mac-studio.sh — Bootstrap Mac Studio (Fedora Asahi) for remote access
# Run this ON THE MAC STUDIO (home machine)

set -euo pipefail

echo "=== Mac Studio Remote Access Setup ==="
echo ""

# ── Step 1: Check if SSH is enabled ─────────────────────────────────
echo "[1/6] Checking SSH configuration..."

# Enable and start SSH
if command -v systemctl &>/dev/null; then
    sudo systemctl enable --now sshd 2>/dev/null || true
    echo "  → SSH enabled"
else
    echo "  → systemctl not found, skipping SSH service"
fi

# ── Step 2: Configure SSH for key-based auth ───────────────────────
echo "[2/6] Configuring SSH for key-based authentication..."

# Create SSH directory if it doesn't exist
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Create authorized_keys file if it doesn't exist
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Add Mac Studio's own key to authorized_keys (for localhost)
if [ -f ~/.ssh/id_ed25519.pub ]; then
    cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
    echo "  → Added local SSH key to authorized_keys"
fi

echo "  → SSH configured for key-based auth"
echo "  → To add laptop key, run:"
echo "     echo 'LAPTOP_PUBLIC_KEY' >> ~/.ssh/authorized_keys"

# ── Step 3: Install/configure wayvnc ───────────────────────────────
echo "[3/6] Setting up wayvnc for VNC remote desktop..."

# Check if wayvnc is installed
if command -v wayvnc &>/dev/null; then
    echo "  → wayvnc already installed: $(wayvnc --version 2>&1 | head -1)"
else
    echo "  → wayvnc not found. Install with:"
    echo "    sudo dnf install wayvnc"
fi

# Check if wayvnc service is enabled
if systemctl --user list-unit-files | grep -q wayvnc.service; then
    echo "  → wayvnc service exists"
else
    echo "  → To enable wayvnc, create ~/.config/systemd/user/wayvnc.service"
    echo "  → Example:"
    echo "    [Unit]"
    echo "    Description=wayvnc"
    echo "    After=graphical.target"
    echo ""
    echo "    [Service]"
    echo "    ExecStart=/usr/bin/wayvnc 0.0.0.0 5910"
    echo ""
    echo "    [Install]"
    echo "    WantedBy=graphical.target"
fi

# ── Step 4: Configure firewall for VNC ─────────────────────────────
echo "[4/6] Configuring firewall for VNC..."

if command -v firewall-cmd &>/dev/null; then
    sudo firewall-cmd --permanent --add-port=5910/tcp 2>/dev/null || true
    sudo firewall-cmd --reload 2>/dev/null || true
    echo "  → Firewall configured for VNC port 5910"
else
    echo "  → firewall-cmd not found, skipping"
fi

# ── Step 5: Install/start Redis ─────────────────────────────────────
echo "[5/6] Setting up Redis..."

if command -v redis-server &>/dev/null; then
    echo "  → Redis installed"
    if command -v systemctl &>/dev/null; then
        sudo systemctl enable --now redis 2>/dev/null || true
        echo "  → Redis service enabled"
    fi
else
    echo "  → Redis not found. Install with:"
    echo "    sudo dnf install redis"
fi

# ── Step 6: Tailscale ───────────────────────────────────────────────
echo "[6/6] Checking Tailscale..."

if command -v tailscale &>/dev/null; then
    echo "  → Tailscale installed"
    if systemctl is-active --quiet tailscaled 2>/dev/null; then
        echo "  → Tailscale is running"
        tailscale status | head -5
    else
        echo "  → Tailscale not running. Start with:"
        echo "    sudo tailscale up"
    fi
else
    echo "  → Tailscale not installed. Install from:"
    echo "    https://tailscale.com/kb/1185/install-macos/"
fi

echo ""
echo "=== Mac Studio Setup Complete ==="
echo ""
echo "Quick reference:"
echo ""
echo "1. Add laptop's SSH key to authorized_keys:"
echo "   echo 'LAPTOP_PUBLIC_KEY' >> ~/.ssh/authorized_keys"
echo ""
echo "2. Start wayvnc for VNC (if not auto-started):"
echo "   wayvnc 0.0.0.0 5910 &"
echo ""
echo "3. Check Tailscale IP:"
echo "   tailscale ip -4"
echo ""
echo "4. From laptop, connect with:"
echo "   ssh juansbiz@100.117.232.15"
echo "   remote-code"
echo "   remote-desktop"
