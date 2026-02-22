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
| `:3000` | Vite dev server (Axolop) |
| `:3002` | Vite dev server |
| `:3005` | Vite dev server |
| `:3006` | Vite dev server (InboxEQ) |
| `:7100` | Henry OS |
| `:18789` | OpenClaw gateway (Axolop) |
| `:18790` | OpenClaw gateway (Henry) |
| `:18791` | OpenClaw gateway (InboxEQ) |
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
| `setup-laptop-remote.sh` | One-shot bootstrap — run once, sets everything up |
| `laptop-host.conf` | Hyprland config for laptop (no blur/shadow, smaller gaps for Intel GPU) |
