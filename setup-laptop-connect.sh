#!/usr/bin/env bash
# setup-laptop-connect.sh — Get Tailscale up and SSH to Mac Studio working
# Run this BEFORE setup-laptop-remote.sh (which does the full bootstrap)
set -euo pipefail

MAC_STUDIO_IP="100.117.232.15"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_KEY_FILE="$SCRIPT_DIR/keys/mac-studio-host-ed25519.pub"

info()  { printf '\033[1;34m=> %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m=> %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m=> %s\033[0m\n' "$*"; }
fail()  { printf '\033[1;31m=> %s\033[0m\n' "$*"; exit 1; }

# ── 1. Install Tailscale ──────────────────────────────────────────────
info "Checking Tailscale..."
if ! command -v tailscale &>/dev/null; then
    info "Installing tailscale..."
    sudo pacman -S --needed --noconfirm tailscale
fi
ok "Tailscale binary found"

# ── 2. Enable + start tailscaled ──────────────────────────────────────
if ! systemctl is-active --quiet tailscaled; then
    info "Starting tailscaled..."
    sudo systemctl enable --now tailscaled
fi
ok "tailscaled is running"

# ── 3. Connect to tailnet if not already ──────────────────────────────
if ! tailscale status &>/dev/null; then
    info "Connecting to Tailscale (browser auth will open)..."
    sudo tailscale up
fi
ok "Tailscale is connected"

# Show current status
tailscale status

# ── 4. Wait for Mac Studio to be reachable ────────────────────────────
info "Pinging Mac Studio at $MAC_STUDIO_IP..."
attempts=0
max_attempts=15
while ! ping -c 1 -W 2 "$MAC_STUDIO_IP" &>/dev/null; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge "$max_attempts" ]; then
        fail "Mac Studio not reachable after $max_attempts attempts. Is it online?"
    fi
    printf '  waiting... (%d/%d)\n' "$attempts" "$max_attempts"
    sleep 2
done
ok "Mac Studio is reachable"

# ── 5. Pre-add host key to known_hosts ────────────────────────────────
if [ ! -f "$HOST_KEY_FILE" ]; then
    fail "Host key file not found: $HOST_KEY_FILE"
fi

mkdir -p ~/.ssh
chmod 700 ~/.ssh

HOST_KEY=$(cat "$HOST_KEY_FILE")
KNOWN_HOSTS_ENTRY="$MAC_STUDIO_IP $HOST_KEY"

if [ -f ~/.ssh/known_hosts ] && grep -qF "$MAC_STUDIO_IP" ~/.ssh/known_hosts; then
    info "Mac Studio already in known_hosts, updating..."
    # Remove old entry and add fresh one
    ssh-keygen -R "$MAC_STUDIO_IP" 2>/dev/null || true
fi

echo "$KNOWN_HOSTS_ENTRY" >> ~/.ssh/known_hosts
chmod 600 ~/.ssh/known_hosts
ok "Mac Studio host key added to known_hosts (no TOFU prompt)"

# ── 6. Test SSH connection ────────────────────────────────────────────
info "Testing SSH to juansbiz@$MAC_STUDIO_IP..."
if ssh -o BatchMode=yes -o ConnectTimeout=10 "juansbiz@$MAC_STUDIO_IP" hostname 2>/dev/null; then
    ok "SSH connection successful!"
else
    warn "SSH connection failed (BatchMode). Possible causes:"
    echo "  - Laptop SSH key not in Mac Studio authorized_keys"
    echo "  - No SSH key generated yet (run: ssh-keygen -t ed25519)"
    echo "  - Key mismatch"
    echo ""
    echo "To fix, copy your public key to Mac Studio:"
    echo "  ssh-copy-id -i ~/.ssh/id_ed25519.pub juansbiz@$MAC_STUDIO_IP"
    exit 1
fi

# ── Done ──────────────────────────────────────────────────────────────
echo ""
ok "All good! You can now:"
echo "  ssh juansbiz@$MAC_STUDIO_IP"
echo "  ./setup-laptop-remote.sh    # full bootstrap (packages, configs, etc.)"
