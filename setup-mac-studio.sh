#!/usr/bin/env bash
# setup-mac-studio.sh — Bootstrap Mac Studio (Fedora Asahi, M1 Max) for remote access
# Run this ON THE MAC STUDIO (home machine)
# Idempotent — safe to re-run

set -euo pipefail

TAILSCALE_IP="100.117.232.15"
VNC_PORT="5910"
WAYVNC_CONFIG_DIR="$HOME/.config/wayvnc"
SSHD_HARDENED="/etc/ssh/sshd_config.d/99-hardened.conf"
WAYVNC_SERVICE="$HOME/.config/systemd/user/wayvnc.service"

echo "=== Mac Studio Remote Access Setup ==="
echo "  System: Fedora Asahi Remix (ARM64, KDE Plasma / Hyprland)"
echo "  Tailscale IP: $TAILSCALE_IP"
echo ""

# ── Step 1: Tailscale ────────────────────────────────────────────────
echo "[1/6] Checking Tailscale..."

if command -v tailscale &>/dev/null; then
    if systemctl is-active --quiet tailscaled 2>/dev/null; then
        TS_IP=$(tailscale ip -4 2>/dev/null || echo "unknown")
        echo "  ✓ Tailscale running — IP: $TS_IP"
        tailscale status | head -5
    else
        echo "  ✗ Tailscale installed but not running"
        echo "    sudo systemctl enable --now tailscaled"
        echo "    sudo tailscale up"
    fi
else
    echo "  ✗ Tailscale not installed"
    echo "    sudo dnf install tailscale"
    echo "    sudo systemctl enable --now tailscaled"
    echo "    sudo tailscale up"
fi
echo ""

# ── Step 2: Hardened SSH config ──────────────────────────────────────
echo "[2/6] Configuring SSH (Tailscale-only, key-based auth)..."

sudo systemctl enable --now sshd 2>/dev/null || true

if [ -f "$SSHD_HARDENED" ]; then
    echo "  ✓ Hardened config exists at $SSHD_HARDENED"
else
    echo "  Creating hardened SSH config..."
    sudo tee "$SSHD_HARDENED" > /dev/null <<'SSHEOF'
# Remote coding access — Tailscale only
AllowUsers juansbiz
PasswordAuthentication no
PermitEmptyPasswords no
PermitRootLogin no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
GSSAPIAuthentication no
MaxAuthTries 3
MaxSessions 5
LoginGraceTime 30s
MaxStartups 3:50:10
ClientAliveInterval 30
ClientAliveCountMax 120
AllowTcpForwarding yes
GatewayPorts no
AllowAgentForwarding yes
X11Forwarding no
LogLevel VERBOSE
ListenAddress 100.117.232.15
ListenAddress 127.0.0.1
SSHEOF
    sudo systemctl reload sshd
    echo "  ✓ Hardened config created and sshd reloaded"
fi

# Verify key settings
PW_AUTH=$(sudo grep -E '^PasswordAuthentication' "$SSHD_HARDENED" 2>/dev/null || echo "not set")
LISTEN=$(sudo grep -E '^ListenAddress' "$SSHD_HARDENED" 2>/dev/null || echo "not set")
echo "  $PW_AUTH"
echo "  $LISTEN"

# Ensure authorized_keys exists with correct permissions
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
KEY_COUNT=$(wc -l < ~/.ssh/authorized_keys)
echo "  ✓ authorized_keys has $KEY_COUNT key(s)"
echo ""

# ── Step 3: wayvnc with TLS auth (Tailscale-only) ───────────────────
echo "[3/6] Setting up wayvnc (TLS + auth, Tailscale-only on port $VNC_PORT)..."

if ! command -v wayvnc &>/dev/null; then
    echo "  ✗ wayvnc not installed — sudo dnf install wayvnc"
    echo ""
else
    echo "  ✓ wayvnc installed"

    # Create config dir
    mkdir -p "$WAYVNC_CONFIG_DIR"

    # Generate TLS certs if missing
    if [ ! -f "$WAYVNC_CONFIG_DIR/tls_key.pem" ]; then
        echo "  Generating self-signed TLS certificate..."
        openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 \
            -nodes -keyout "$WAYVNC_CONFIG_DIR/tls_key.pem" \
            -out "$WAYVNC_CONFIG_DIR/tls_cert.pem" \
            -subj "/CN=wayvnc" 2>/dev/null
        chmod 600 "$WAYVNC_CONFIG_DIR/tls_key.pem"
        echo "  ✓ TLS certificate generated"
    else
        echo "  ✓ TLS certificate exists"
    fi

    # Generate RSA key if missing
    if [ ! -f "$WAYVNC_CONFIG_DIR/rsa_key.pem" ]; then
        openssl genrsa -out "$WAYVNC_CONFIG_DIR/rsa_key.pem" 4096 2>/dev/null
        chmod 600 "$WAYVNC_CONFIG_DIR/rsa_key.pem"
        echo "  ✓ RSA key generated"
    else
        echo "  ✓ RSA key exists"
    fi

    # Create/verify wayvnc config (bound to Tailscale IP, auth enabled)
    if [ -f "$WAYVNC_CONFIG_DIR/config" ]; then
        echo "  ✓ wayvnc config exists"
        ADDR=$(grep -E '^address=' "$WAYVNC_CONFIG_DIR/config" 2>/dev/null || echo "not set")
        AUTH=$(grep -E '^enable_auth=' "$WAYVNC_CONFIG_DIR/config" 2>/dev/null || echo "not set")
        echo "    $ADDR"
        echo "    $AUTH"
    else
        echo "  Creating wayvnc config (Tailscale-only + auth)..."
        read -rsp "  Enter VNC password: " VNC_PASS
        echo ""
        cat > "$WAYVNC_CONFIG_DIR/config" <<VNCEOF
address=$TAILSCALE_IP
port=$VNC_PORT
enable_auth=true
username=juansbiz
password=$VNC_PASS
private_key_file=$WAYVNC_CONFIG_DIR/tls_key.pem
certificate_file=$WAYVNC_CONFIG_DIR/tls_cert.pem
rsa_private_key_file=$WAYVNC_CONFIG_DIR/rsa_key.pem
VNCEOF
        chmod 600 "$WAYVNC_CONFIG_DIR/config"
        echo "  ✓ wayvnc config created"
    fi

    # Create/verify systemd user service
    if [ -f "$WAYVNC_SERVICE" ]; then
        echo "  ✓ wayvnc systemd service exists"
    else
        echo "  Creating wayvnc systemd user service..."
        mkdir -p "$(dirname "$WAYVNC_SERVICE")"
        cat > "$WAYVNC_SERVICE" <<'SVCEOF'
[Unit]
Description=wayvnc - Hyprland VNC Server
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/wayvnc --max-fps=60 --keyboard=us
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical-session.target
SVCEOF
        systemctl --user daemon-reload
        systemctl --user enable wayvnc.service
        echo "  ✓ wayvnc service created and enabled"
    fi

    # Check if running
    if systemctl --user is-active --quiet wayvnc.service 2>/dev/null; then
        echo "  ✓ wayvnc is running on $TAILSCALE_IP:$VNC_PORT"
    else
        echo "  Starting wayvnc..."
        systemctl --user start wayvnc.service
        echo "  ✓ wayvnc started"
    fi
fi
echo ""

# ── Step 4: Firewalld — trust tailscale0 ──────────────────────────────
echo "[4/6] Firewalld: ensuring tailscale0 is in trusted zone..."

if command -v firewall-cmd &>/dev/null; then
    ZONE=$(sudo firewall-cmd --get-zone-of-interface=tailscale0 2>/dev/null)
    if [ "$ZONE" != "trusted" ]; then
        sudo firewall-cmd --zone=trusted --add-interface=tailscale0 --permanent
        sudo firewall-cmd --reload
        echo "  ✓ tailscale0 added to trusted zone"
    else
        echo "  ✓ tailscale0 already in trusted zone"
    fi
else
    echo "  — firewalld not installed, skipping"
fi
echo ""

# ── Step 5: Hyprland keyboard passthrough ────────────────────────────
echo "[5/6] Hyprland VNC passthrough..."

HYPR_CONF="$HOME/.config/hypr/hyprland.conf"
if [ -f "$HYPR_CONF" ] && grep -q "wayvnc-passthrough" "$HYPR_CONF" 2>/dev/null; then
    echo "  ✓ Keyboard passthrough submap already configured"
else
    echo "  ⚠ Add VNC passthrough submap to $HYPR_CONF:"
    echo "    bind = SUPER, F10, submap, wayvnc-passthrough"
    echo "    submap = wayvnc-passthrough"
    echo "    bind = SUPER, F10, submap, reset"
    echo "    submap = reset"
fi
echo ""

# ── Step 6: Install mosh (optional, for flaky connections) ───────────
echo "[6/6] Checking mosh..."

if command -v mosh-server &>/dev/null; then
    echo "  ✓ mosh-server installed"
else
    echo "  ✗ mosh not installed — sudo dnf install mosh"
fi
echo ""

# ── Summary ──────────────────────────────────────────────────────────
echo "=== Setup Complete ==="
echo ""
echo "From laptop, connect with:"
echo "  SSH:  ssh juansbiz@$TAILSCALE_IP"
echo "  Mosh: mosh juansbiz@$TAILSCALE_IP"
echo "  VNC:  Connect to $TAILSCALE_IP:$VNC_PORT (TLS, auth required)"
echo ""
echo "SSH listens ONLY on Tailscale ($TAILSCALE_IP) and localhost."
echo "wayvnc listens ONLY on Tailscale ($TAILSCALE_IP:$VNC_PORT) with TLS + password auth."
echo "Password authentication is DISABLED — pubkey only."
echo ""
echo "To add a new laptop key:"
echo "  echo 'ssh-ed25519 AAAA... user@host' >> ~/.ssh/authorized_keys"
