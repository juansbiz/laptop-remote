# Laptop Remote Access

Bootstrap an EndeavourOS laptop for full remote access to the home M1 Max (Fedora Asahi) over Tailscale.

## Three layers

| Layer | Tool | Use case |
|-------|------|----------|
| Coding | VS Code Remote SSH | GUI on laptop, files/compute on home |
| Full desktop | wayvnc + TigerVNC | Stream Hyprland desktop |
| Terminal | SSH + mosh + tmux | Claude Code, quick terminal work |

## Usage

```bash
git clone https://github.com/juansbiz/laptop-remote.git
cd laptop-remote
chmod +x setup-laptop-remote.sh
./setup-laptop-remote.sh
```

Then copy `laptop-host.conf` to `~/.config/hypr/host.conf` on the laptop.

## Files

- `setup-laptop-remote.sh` — Installs packages, configures SSH, creates connection scripts
- `laptop-host.conf` — Hyprland config for laptop (lighter effects for Intel GPU)
