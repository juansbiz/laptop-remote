#!/usr/bin/env bash
# setup-dev-deps.sh — Install development dependencies for AxolopCRM
# Run this ON THE LAPTOP (EndeavourOS)

set -euo pipefail

echo "=== Installing Development Dependencies for AxolopCRM ==="
echo ""

# ── Node.js & npm ───────────────────────────────────────────────
echo "[1/5] Installing Node.js and npm..."
if command -v node &>/dev/null; then
    echo "  → Node.js already installed: $(node --version)"
else
    sudo pacman -S --needed --noconfirm nodejs npm
    echo "  → Node.js installed: $(node --version)"
fi

# ── pnpm (faster than npm) ───────────────────────────────────────
echo "[2/5] Installing pnpm..."
if command -v pnpm &>/dev/null; then
    echo "  → pnpm already installed: $(pnpm --version)"
else
    sudo pacman -S --needed --noconfirm pnpm
    echo "  → pnpm installed: $(pnpm --version)"
fi

# ── Docker ───────────────────────────────────────────────────────
echo "[3/5] Installing Docker..."
if command -v docker &>/dev/null; then
    echo "  → Docker already installed: $(docker --version)"
else
    sudo pacman -S --needed --noconfirm docker docker-compose
    echo "  → Docker installed: $(docker --version)"
    echo ""
    echo "  → Enabling Docker service..."
    sudo systemctl enable --now docker
    echo "  → Adding user to docker group..."
    sudo usermod -aG docker "$USER"
    echo ""
    echo "  ⚠️  Log out and back in for Docker group to take effect!"
fi

# ── PostgreSQL client ───────────────────────────────────────────
echo "[4/5] Installing PostgreSQL client..."
if command -v psql &>/dev/null; then
    echo "  → psql already installed: $(psql --version)"
else
    sudo pacman -S --needed --noconfirm postgresql
    echo "  → psql installed"
fi

# ── VS Code (if not installed) ──────────────────────────────────
echo "[5/5] Checking VS Code..."
if command -v code &>/dev/null; then
    echo "  → VS Code already installed"
else
    echo "  → VS Code not found. Install with: yay -S visual-studio-code-bin"
fi

echo ""
echo "=== Development Dependencies Installed ==="
echo ""
echo "Next steps:"
echo "  1. Log out and back in (if Docker was installed)"
echo "  2. Clone AxolopCRM: git clone https://github.com/juansbiz/axolopcrm.git"
echo "  3. Install deps: cd axolopcrm && npm install"
echo "  4. Start dev: npm run dev"
echo ""
echo "AxolopCRM will be available at:"
echo "  • Frontend: http://localhost:3000"
echo "  • Backend:  http://localhost:3002"
