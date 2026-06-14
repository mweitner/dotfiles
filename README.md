# Dotfiles – Fedora Installation & Setup

Complete Fedora Workstation setup with Wayland/Sway, development tools, home office VPN support, and Yocto build environment.

## Quick Start

```bash
# Clone dotfiles to home
git clone <repo> ~/dotfiles

# Run base installation
bash ~/dotfiles/install-fedora.sh

# Optionally install dev tools and pinned VS Code version
bash ~/dotfiles/install-fedora-dev.sh

# Reboot and start Sway
reboot
# or:
sway
```

## Installation Scripts

### `install-fedora.sh`

Base system setup for Fedora Workstation (41+). Idempotent — safe to re-run.

**Phases:**

1. **Phase 1**: Package installation (Sway, tools, VPN, Docker, fonts, etc.)
2. **Phase 2**: Config symlinks (sway, waybar, fish, git, etc.)
3. **Phase 3**: Services & daemon config (NetworkManager, greetd, tlp, TLP dock tuning, etc.)
4. **Phase 4**: Yocto shared directories (/opt/yocto/shared)

**Options:**

```bash
install-fedora.sh [--skip-packages] [--skip-symlinks] [--skip-services] [--skip-docker] \
                  [--skip-docker-daemon-config] [--skip-dev] \
                  [--with-ssh-secrets] [--with-netrc-secrets] [--with-1password-ssh-agent]
```

**Key Features:**

- Wayland/Sway + Waybar, wofi, foot terminal
- Modern CLI tools (ripgrep, fd-find, fzf, zoxide, htop)
- NetworkManager with iwd backend
- VPN: GlobalProtect (gpclient) + openconnect fallback
- Docker (native Fedora setup)
- Yocto build environment (/opt/yocto)
- **Home office VPN DNS fix**: `fix-vpn-dns-browser` (auto-installed)

### `install-fedora-dev.sh`

Development tools & environment integration. Can be run independently.

**Includes:**

- Neovim + git-delta + meld
- Go, pre-commit, GitHub CLI, plantuml, pandoc
- MQTT tools (mosquitto, MQTT Explorer)
- Hawkbit upload tooling (hbc)
- Yocto host build dependencies (gawk, diffstat, chrpath, socat, perl, etc.)
- VS Code (version-pinnable)
- Azure CLI

**Version pins (override via environment):**

```bash
VSCODE_VERSION=1.115 bash install-fedora-dev.sh    # Pin VS Code to 1.115.x
VSCODE_VERSION=""    bash install-fedora-dev.sh    # Track latest
```

### `install-ubuntu-bash.sh` & `install.sh`

Legacy Ubuntu/Bash setups. For reference only; primary target is Fedora + fish.

## Home Office VPN & GitHub Controller Access

### Problem

From Fedora Workstation with Liebherr VPN, GitHub Controller API fails due to browser DNS bypass (Firefox DoH, Chrome socket caching).

### Solution

After connecting to VPN, run:

```bash
fix-vpn-dns-browser       # Auto-detects VPN interface, fixes all layers
test-vpn-dns              # Verify OS DNS resolution → 10.243.65.137
test-browser-dns          # Verify HTTPS connectivity
```

The script:

1. Configures systemd-resolved domain routing for `liebherr.com`
2. Disables Firefox DNS-over-HTTPS permanently
3. Clears Chrome/Firefox caches
4. Flushes system DNS cache
5. Restarts browsers (optional)

### Full Documentation

→ `~/document/wiki/doc-engine/source/analysis/homeoffice-github-controller-access/`

Includes:

- [README.md](../document/wiki/doc-engine/source/analysis/homeoffice-github-controller-access/README.md) – Overview
- [CHEATSHEET.md](../document/wiki/doc-engine/source/analysis/homeoffice-github-controller-access/CHEATSHEET.md) – Quick commands
- [RUNBOOK-vpn-dns-browser-fix.md](../document/wiki/doc-engine/source/analysis/homeoffice-github-controller-access/RUNBOOK-vpn-dns-browser-fix.md) – Detailed guide & troubleshooting

## Directory Structure

```
~/dotfiles/
├── install-fedora.sh               # Base Fedora setup
├── install-fedora-dev.sh           # Dev tools (independently runnable)
├── install.sh                      # Legacy (refer to install-fedora.sh)
├── shell/                          # Executable scripts
│   ├── vpn-on                      # VPN connection script
│   ├── fix-vpn-dns-browser         # VPN DNS fix (NEW)
│   ├── setup-machine-network-profiles.sh
│   ├── setup-docker-fedora-native.sh
│   ├── monitor-*                   # Display layout helpers
│   ├── yocto/                      # Yocto/LPO build scripts
│   └── ...
├── fish/
│   ├── config.fish                 # Main config (sources vpc-dns-fix functions)
│   ├── conf.d/                     # Hook/plugin configs
│   └── functions/
│       ├── vpn-dns-fix.fish        # VPN DNS functions (NEW)
│       └── ...
├── sway/                           # Sway WM config
├── waybar/                         # Waybar status bar
├── i3/                             # i3 WM config (legacy)
├── tmux/                           # tmux multiplexer
├── tmuxp/                          # tmuxp session files
├── git/                            # Git config
├── zsh/ & bash/                    # Shell configs
├── dnsmasq/                        # DNS/DHCP profiles
├── greetd/                         # Display manager config
├── systemd/                        # systemd service/timer configs
├── tlp/                            # Power management config
├── mako/                           # Wayland notifications
├── qutebrowser/                    # Qutebrowser browser config
├── remmina/                        # Remote desktop profiles
├── docs/doc-engine/                # Doc build system (Sphinx)
└── .secrets/                       # ⚠️ Private (not checked in)
    ├── ssh/                        # SSH keys & profiles
    ├── yocto/keys/                 # Yocto keys (prod/dev)
    └── ...
```

## Fish Shell Functions

Auto-sourced from `~/.config/fish/functions/`. Key additions:

```fish
fix-vpn-dns-browser [interface]    # Fix VPN DNS + browser cache
test-vpn-dns                       # Test OS DNS resolution
test-browser-dns                   # Test HTTPS connectivity
```

Other available:

- `compress <dir>` – Create tar.gz
- `zipdir <dir>` – Create .zip (Windows-friendly)
- `wikipedia <query>` – Search Wikipedia in qutebrowser
- `duckduckgo <query>` – Search DuckDuckGo in qutebrowser

## Secrets & Private Data

### `.secrets/` Directory Structure

```
.secrets/
├── .gitignore              # Exclude all from git
├── ssh/                    # SSH keys
│   └── dev-pc/.ssh/        # Machine-specific SSH profile
├── yocto/keys/             # Yocto build keys
│   ├── llp/{dev,prod}/
│   ├── lpo/{dev,prod}/
│   └── ...
├── home/$USER/
│   └── .netrc              # Credentials file (opt-in install)
├── git/                    # Git commit signing keys
│   └── ...
├── microsoft/              # Azure/Teams credentials
├── ci/                     # GitHub Actions secrets
└── iot-gateways/           # Device provisioning
```

Install secrets selectively:

```bash
install-fedora.sh --with-ssh-secrets         # Copy ~/.ssh from .secrets
install-fedora.sh --with-netrc-secrets       # Copy ~/.netrc
install-fedora.sh --with-1password-ssh-agent # Set up 1Password SSH agent
```

## Common Tasks

### Update Fedora packages

```bash
sudo dnf upgrade
bash install-fedora.sh --skip-symlinks   # Refresh config symlinks after major update
```

### Switch Yocto key profile

```bash
switch-yocto-keys-profile llp prod       # Switch llp from dev → prod keys
switch-yocto-keys-profile lpo dev        # Switch lpo from prod → dev keys
```

### Set up Yocto build

```bash
setup-yocto-project --project linux-lpo  # Initialize LPO Yocto
cd ~/lpo-dev/linux-lpo
lpo-build bitbake -u knotty -v lpo-display-image
```

### Connect to Liebherr VPN (home office)

```bash
vpn-on                                   # Interactive SAML browser flow
fix-vpn-dns-browser                      # Fix DNS + browser cache
test-vpn-dns && test-browser-dns         # Verify connectivity
```

### Remote desktop (Windows/hop-PC)

```bash
remmina                                  # Open GUI; profiles stored in ~/.config/remmina/
```

## Troubleshooting

### VPN DNS still resolves wrong IP?

See [RUNBOOK-vpn-dns-browser-fix.md](../document/wiki/doc-engine/source/analysis/homeoffice-github-controller-access/RUNBOOK-vpn-dns-browser-fix.md) **Troubleshooting** section.

### Pre-commit SSL errors (Python 3.14)?

```bash
pre-commit-helper --fix-config                # Patch node/golang to system
setup-pre-commit                              # Re-run setup + pre-cache
```

See `~/document/wiki/...` for details.

### Yocto build fails?

```bash
setup-yocto-project --help                    # Project initialization
yocto-prefetch-source --help                  # Manual source fetch
```

## References

- [Sway Documentation](https://swaywm.org/)
- [Fedora Minimal Install](https://docs.fedoraproject.org/)
- [Yocto Project](https://www.yoctoproject.org/)
- [Liebherr Internal Wiki](file:///mnt/nas/...)
- [GitHub Controller API](https://lis-github.liebherr.com/)

---

**Last Updated**: 2026-05-26
**Target**: Fedora 41+ Workstation (Sway/Wayland)
**Maintained**: Local user dotfiles & wiki integration
