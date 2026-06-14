# Dotfiles - Fedora Installation and Setup

Personal Fedora Workstation setup with Sway/Wayland, fish-based shell workflows, development
tooling, home-office VPN helpers, and Yocto-oriented automation.

Upcoming first release: `0.1.0`

- Release notes: [CHANGELOG.md](CHANGELOG.md)
- Contribution workflow: [CONTRIBUTING.md](CONTRIBUTING.md)
- AI editing and validation rules: [.AI-GUIDELINES.md](.AI-GUIDELINES.md)

## Quick Start

```bash
# Clone dotfiles to home
git clone <repo> ~/dotfiles

# Run base installation
bash ~/dotfiles/install-fedora.sh

# Optionally install dev tools and a pinned or latest VS Code
bash ~/dotfiles/install-fedora-dev.sh

# Reboot and start Sway
reboot
# or:
sway
```

## What This Repo Covers

- Fedora-first workstation bootstrap
- Wayland/Sway desktop configuration
- Fish, Bash, and Zsh shell setup
- Developer tooling, editors, and CLI utilities
- Yocto helper scripts and key-profile switching
- VPN, DNS, and remote-access helpers
- Personal documentation built with Sphinx

## Installation Scripts

### `install-fedora.sh`

Base system setup for Fedora Workstation 41+. The script is intended to be idempotent and safe to
re-run after updates or partial setup.

Phases:

1. Package installation for desktop, network, and development tools
2. Config symlinks for shell, editor, desktop, and Git setup
3. Services and daemon configuration for system integration
4. Shared Yocto directory preparation under `/opt/yocto`

Usage:

```bash
install-fedora.sh [--skip-packages] [--skip-symlinks] [--skip-services] [--skip-docker] \
                  [--skip-docker-daemon-config] [--skip-dev] \
                  [--with-ssh-secrets] [--with-netrc-secrets] [--with-1password-ssh-agent]
```

Highlights:

- Sway, Waybar, wofi, foot, and related Wayland tooling
- Modern CLI tools such as `rg`, `fd`, `fzf`, `zoxide`, and `htop`
- NetworkManager with iwd backend
- Docker using a native Fedora setup path
- Yocto build environment preparation
- Auto-installed VPN DNS repair helper workflow

### `install-fedora-dev.sh`

Optional development tooling bootstrap that can be run independently from the base install.

Includes:

- Neovim, git-delta, meld, and general editor tooling
- Go, pre-commit, GitHub CLI, PlantUML, and pandoc
- MQTT tools such as mosquitto clients and MQTT Explorer
- Yocto host build dependencies
- VS Code installation with version pinning support
- Azure CLI

Example:

```bash
VSCODE_VERSION=1.115 bash install-fedora-dev.sh
VSCODE_VERSION="" bash install-fedora-dev.sh
```

### `install-ubuntu-bash.sh` and `install.sh`

Legacy Ubuntu and Bash-focused setup paths are kept for reference. The primary target for active
maintenance is Fedora with fish and Sway.

## Documentation and Validation

The repository includes a local Sphinx documentation workspace in [doc-engine](doc-engine).

## Docs Publishing

[![Docs Pages](https://github.com/mweitner/dotfiles/actions/workflows/docs-pages.yml/badge.svg)](https://github.com/mweitner/dotfiles/actions/workflows/docs-pages.yml)

- Workflow file: [.github/workflows/docs-pages.yml](.github/workflows/docs-pages.yml)
- Published site URL: <https://mweitner.github.io/dotfiles/>

Activation notes:

1. Ensure GitHub Pages is configured to deploy from GitHub Actions.
2. Push changes to main, or trigger the workflow manually from the Actions tab.
3. Check the deploy job output for the final page URL.

Common validation commands:

```bash
make -C doc-engine html
pre-commit run --all-files
```

Use these before tagging a release or after larger changes to scripts, docs, or shell config.

## Home Office VPN and DNS Repair

This repo includes helpers for the case where browser DNS behavior bypasses VPN-provided name
resolution.

After connecting to VPN, run:

```bash
fix-vpn-dns-browser
test-vpn-dns
test-browser-dns
```

The workflow is designed to:

1. Configure systemd-resolved domain routing
2. Disable conflicting browser DNS behavior where needed
3. Clear DNS-related caches
4. Re-check browser connectivity

Additional background is documented in [INTEGRATION-VPN-DNS-FIX.md](INTEGRATION-VPN-DNS-FIX.md).

## Repository Layout

```text
~/dotfiles/
|- install-fedora.sh
|- install-fedora-dev.sh
|- install.sh
|- shell/
|- fish/
|- sway/
|- waybar/
|- tmux/
|- tmuxp/
|- git/
|- systemd/
|- remmina/
|- doc-engine/
`- .secrets/
```

Key areas:

- `shell/`: executable helpers, including Yocto and network tooling
- `fish/`: shell configuration and interactive helper functions
- `sway/`, `waybar/`, `foot/`, `mako/`: desktop environment configuration
- `systemd/`, `greetd/`, `tlp/`: system integration and service configuration
- `doc-engine/`: personal documentation source and local HTML build setup
- `.secrets/`: private material that must never be committed

## Common Tasks

### Update Fedora packages

```bash
sudo dnf upgrade
bash install-fedora.sh --skip-symlinks
```

### Set up a Yocto build workspace

```bash
setup-yocto-project --project linux-lpo
cd ~/lpo-dev/linux-lpo
lpo-build bitbake -u knotty -v lpo-display-image
```

### Switch Yocto key profile

```bash
switch-yocto-keys-profile llp prod
switch-yocto-keys-profile lpo dev
```

### Open remote desktop profiles

```bash
remmina
```

## Secrets and Private Data

Private material belongs under `.secrets/` and should stay out of Git.

Use the install flags only when you intentionally want to copy local private data into a machine
setup:

```bash
install-fedora.sh --with-ssh-secrets
install-fedora.sh --with-netrc-secrets
install-fedora.sh --with-1password-ssh-agent
```

Do not document or commit real credentials, tokens, or internal private keys.

## Troubleshooting

### Pre-commit problems

```bash
pre-commit run --all-files
pre-commit-helper --fix-config
setup-pre-commit
```

### VPN or DNS still looks wrong

Re-run the repair helpers and confirm the expected target resolves through the VPN path.

### Yocto build setup fails

```bash
setup-yocto-project --help
yocto-prefetch-source --help
```

## References

- [Sway Documentation](https://swaywm.org/)
- [Fedora Documentation](https://docs.fedoraproject.org/)
- [Yocto Project](https://www.yoctoproject.org/)

## Release Planning

The next intended milestone is `0.1.0`, which captures the first documented Fedora-first baseline
for workstation bootstrap, development tooling, documentation, and validation.
