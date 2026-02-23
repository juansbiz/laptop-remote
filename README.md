# Laptop Remote Access

Bootstrap an EndeavourOS laptop (2018 Mac i5) for full remote access to the home M1 Max (Fedora Asahi) over Tailscale.

## What this sets up

| Layer | Tool | Use case |
|-------|------|----------|
| **Coding** | VS Code Remote SSH | GUI on laptop, files/compute on home |
| **Full desktop** | wayvnc + TigerVNC | Stream Hyprland desktop to laptop |
| **Terminal** | SSH + mosh + tmux | Claude Code, quick terminal work |

All traffic runs over Tailscale (WireGuard encrypted, NAT-traversing).

---

## Quick Start (If SSH key is already on home machine)

```bash
# Clone and run setup
git clone https://github.com/juansbiz/laptop-remote.git
cd laptop-remote
chmod +x setup-laptop-remote.sh
./setup-laptop-remote.sh
```

---

## Mac Studio Setup (Home Machine)

If you're setting up the Mac Studio for the first time or need to reconfigure:

```bash
# Clone this repo on Mac Studio
git clone https://github.com/juansbiz/laptop-remote.git
cd laptop-remote
chmod +x setup-mac-studio.sh
./setup-mac-studio.sh
```

**What the script does:**
1. Enables SSH server
2. Configures key-based authentication
3. Checks/configures wayvnc for VNC remote desktop
4. Configures firewall for VNC port 5910
5. Sets up Redis (if installed)
6. Verifies Tailscale is running

### Manual Mac Studio Setup (if script doesn't work)

```bash
# 1. Enable SSH
sudo systemsetup -f -setremotelogin on

# 2. Add laptop's SSH key
echo 'LAPTOP_PUBLIC_KEY' >> ~/.ssh/authorized_keys

# 3. Start wayvnc (for VNC)
wayvnc 0.0.0.0 5910 &

# 4. Check Tailscale
sudo tailscale up
tailscale ip -4
```

---

## Step-by-step from the laptop

### 1. Install git (if not already)

```bash
sudo pacman -S --needed git
```

### 2. Clone this repo

```bash
git clone https://github.com/juansbiz/laptop-remote.git
cd laptop-remote
```

### 3. Run the setup script

```bash
chmod +x setup-laptop-remote.sh
./setup-laptop-remote.sh
```

**What the script does automatically:**
1. Installs packages: `tailscale openssh mosh tmux tigervnc starship zoxide fzf bat ripgrep fd`
2. Enables Tailscale (will prompt you to authenticate if needed)
3. Generates an SSH keypair (`~/.ssh/id_ed25519`)
4. Copies the key to the home machine via `ssh-copy-id` (you'll enter your password **once**)
5. Disables password auth on home machine (pubkey-only from now on)
6. Writes SSH config with two hosts: `home` (with port forwarding) and `home-lite` (terminal only)
7. Creates connection scripts in `~/.local/bin/`
8. Installs VS Code Remote SSH extension
9. Copies `laptop-host.conf` to `~/.config/hypr/host.conf` and wires it into Hyprland

### 4. Make sure `~/.local/bin` is in your PATH

Add to `~/.bashrc` if not already there:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

### 5. Install Ghostty (AUR — not in official repos)

```bash
yay -S ghostty
```

### 6. Install VS Code (for remote development)

```bash
# Install VS Code
yay -S visual-studio-code-bin

# Install Remote SSH extension
code --install-extension ms-vscode-remote.remote-ssh
```

### 7. Install Development Dependencies (optional, for local AxolopCRM dev)

```bash
chmod +x setup-dev-deps.sh
./setup-dev-deps.sh
```

---

## ⚠️ Manual SSH Key Setup (If Away From Home)

If you're not at home and can't run `ssh-copy-id`, follow these steps:

### Step 1: Get your public key

Your public key was generated during setup. Run:
```bash
cat ~/.ssh/id_ed25519.pub
```

Copy the entire output (starts with `ssh-ed25519`).

### Step 2: Add to home machine (when you return)

SSH into your Mac Studio and run:
```bash
echo "YOUR_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
```

Or use the Mac Studio directly to add the key.

---

## Development Dependencies (AxolopCRM)

For developing AxolopCRM locally, install these dependencies:

### Core Runtime

```bash
# Node.js 18+ and npm (required for AxolopCRM)
sudo pacman -S --needed nodejs npm

# pnpm (optional, faster than npm)
sudo pacman -S --needed pnpm
```

### Docker (for backend services)

```bash
# Docker and Docker Compose
sudo pacman -S --needed docker docker-compose

# Enable and start Docker
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
# Log out and back in for group changes to take effect
```

### Database Tools (optional)

```bash
# PostgreSQL client (for direct DB access)
sudo pacman -S --needed postgresql
```

### Quick Install All Dev Deps

```bash
chmod +x setup-dev-deps.sh
./setup-dev-deps.sh
```

---

## AxolopCRM Tech Stack

| Layer | Technology |
|-------|------------|
| **Frontend** | React 18, Vite, TailwindCSS, Framer Motion, Radix UI |
| **Backend** | Node.js, Express |
| **Database** | PostgreSQL (Supabase) |
| **Cache** | Redis |
| **Vector DB** | ChromaDB (AI features) |
| **Email** | SendGrid, Resend |
| **Auth** | JWT, Google OAuth |
| **Payments** | Stripe |
| **Telephony** | Twilio, Telnyx |
| **Testing** | Jest, Playwright |
| **Deployment** | Docker, Vercel, Railway |

### AxolopCRM Quick Commands

```bash
# Install dependencies
npm install

# Start with Docker backend
npm run docker:up        # Starts Backend + Redis in Docker (port 3002)
npm run dev:vite         # Starts Frontend (port 3000)

# Or start everything
npm run dev

# Access locally
# Frontend: http://localhost:3000
# Backend API: http://localhost:3002

# Run tests
npm run test:auth
npm run verify:schema
```

---

## Daily usage

### Terminal coding session
```bash
remote-code                    # SSH + tmux, Claude Code ready
```

### Terminal with port forwarding (view dev apps in laptop browser)
```bash
remote-code --ports            # Forwards all dev server ports
# Then open localhost:3000 → Axolop, localhost:7100 → Henry OS, etc.
```

### Unstable WiFi (mosh survives disconnects)
```bash
remote-code --mosh
```

### Full desktop (browse, file manager, everything)
```bash
remote-desktop                 # Opens VNC viewer
# Super+Escape → passthrough mode (local Hyprland shortcuts OFF)
# Use the remote desktop normally — Super key works there
# Super+Escape again → local shortcuts back ON
```

### VS Code (full IDE, remote files)
```bash
code --remote ssh-remote+home /home/juansbiz/Desktop/CODE
```

### Close everything
```bash
remote-disconnect
```

---

## Port forwarding reference

When using `remote-code --ports` or `ssh home`:

| Laptop localhost | Home service |
|------------------|-------------|
| `:3000` | Axolop CRM Frontend (Vite) |
| `:3002` | Axolop CRM Backend (Express API) |
| `:7100` | Henry OS |
| `:18789` | OpenClaw gateway (Axolop) |
| `:18790` | OpenClaw gateway (Henry) |
| `:8384` | Syncthing |

---

## VNC credentials

- **Username:** `juansbiz`
- **Password:** (same as the one you set up)
- **Port:** `5910` on Tailscale IP `100.117.232.15`

---

## Troubleshooting

### Can't connect at all
```bash
# Check Tailscale
tailscale status
ping 100.117.232.15

# If Tailscale not connected:
sudo tailscale up
```

### SSH asks for password (key not working)
```bash
# Re-copy key
ssh-copy-id -i ~/.ssh/id_ed25519.pub juansbiz@100.117.232.15
```

### VNC viewer won't connect
```bash
# Check wayvnc is running on home machine
ssh home-lite "systemctl --user status wayvnc"

# Restart it
ssh home-lite "systemctl --user restart wayvnc"
```

### Hyprland shortcuts don't work in VNC
Press `Super+Escape` — you're probably still in passthrough mode. Press it again to toggle back.

---

## Files

| File | What it does |
|------|-------------|
| `setup-laptop-remote.sh` | One-shot bootstrap for laptop — run once, sets everything up |
| `setup-dev-deps.sh` | Installs development dependencies for AxolopCRM (Node.js, Docker, pnpm) |
| `setup-mac-studio.sh` | Bootstrap script for Mac Studio (home machine) |
| `laptop-host.conf` | Hyprland config for laptop (no blur/shadow, smaller gaps for Intel GPU) |
