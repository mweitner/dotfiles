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
- Wayland-native screenshot and screen-recording helpers
- Fish, Bash, and Zsh shell setup
- Developer tooling, editors, and CLI utilities
- Yocto helper scripts and key-profile switching
- VPN, DNS, and remote-access helpers
- Personal documentation built with Sphinx

For the current linux-dps Scarthgap release work, the host-side helpers stay
generic and project-specific validation still lives in the wiki. The main entry
points remain `setup-yocto-project`, `llp-yocto-build`, and the Yocto helper
wrappers under `shell/yocto`, which are used for rc2 validation of the build,
WIC generation, and boot-related workflow.

## Cross-Repo Documentation Contract

This repository is intentionally host-focused and automation-focused.

- dotfiles repo owns host setup, helper scripts, wrappers, and local tooling
- project wiki repos own process, architecture, target behavior, and runbooks
- product development repos own implementation (layers, recipes, manifests, CI)

Use this split during updates:

1. If a dotfiles helper changes, update the matching wiki usage docs.
2. If project workflow docs change, verify helper names and options still match dotfiles.
3. If product behavior changes, refresh both wiki process docs and dotfiles examples.

For Yocto topics, keep instructions generic in dotfiles and move project-specific
details to the corresponding wiki collection.

Example pattern:

- dotfiles: document generic helper usage (setup, build wrapper, key switching)
- wiki: document a specific project flow (for example LLP, LPO, DPS)

## German Umlauts on US Keyboard (Fedora + Sway)

This setup keeps an English keyboard layout and English system settings, while still allowing fast
German text input (for example in documentation repos).

Default in this repo:

- Sway keyboard layout stays `us` with variant `intl` (US-International with dead keys)
- Compose key is mapped to Menu key via `compose:menu`

Preferred umlaut input with US-International:

- `"` then `a` -> a-umlaut
- `"` then `o` -> o-umlaut
- `"` then `u` -> u-umlaut

Compose fallback sequences:

- `Menu`, then `"`, then `a` -> a-umlaut
- `Menu`, then `"`, then `o` -> o-umlaut
- `Menu`, then `"`, then `u` -> u-umlaut
- `Menu`, then `s`, then `s` -> sharp-s
- Use uppercase letters for A-umlaut, O-umlaut, U-umlaut

Verification:

```bash
swaymsg -t get_inputs | rg -n "xkb_layout|xkb_active_layout_name|xkb_options"
```

Recommended day-to-day usage:

- Use `"` + letter for umlauts (`"` + `a/o/u`)
- Use `Menu` + `s` + `s` for sharp-s

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
- `grimshot.sh` and `wf-record.sh` for screenshots and browser/player screencasts
- Modern CLI tools such as `rg`, `fd`, `fzf`, `zoxide`, and `htop`
- NetworkManager with iwd backend
- Docker using a native Fedora setup path
- Yocto build environment preparation
- Auto-installed VPN DNS repair helper workflow

### `install-fedora-dev.sh`

Optional development tooling bootstrap that can be run independently from the base install.

Includes:

- Neovim, git-delta, meld, and general editor tooling
- Go, Rust toolchain, pre-commit, GitHub CLI, PlantUML, pandoc, and PDF build support for Sphinx
- `cross` for Windows release builds of the SAT600 field backup tool
- MQTT tools such as mosquitto clients and MQTT Explorer
- Yocto host build dependencies
- VS Code installation with version pinning support
- Azure CLI

Example:

```bash
VSCODE_VERSION=1.115 bash install-fedora-dev.sh
VSCODE_VERSION="" bash install-fedora-dev.sh
cargo build --release
cross build --release --target x86_64-pc-windows-gnu
```

PDF output for the local documentation workspace is available after the dev
script has installed the required LaTeX tooling:

```bash
make -C doc-engine latexpdf
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

### Stream SWU update over SSH (cross-project)

```bash
# Use explicit SWU path
swupdate-ssh-stream --host root@192.168.3.88 \
    --swu ~/ems-dev/linux-dps-scarthgap/build-docker/tmp/deploy/images/imx6s-mcg/dps-image-imx6s-mcg.swu

# Or auto-discover newest SWU from build output
swupdate-ssh-stream --host root@192.168.3.88 --find-latest --machine imx6s-mcg

# Preflight-only check (no update transfer)
swupdate-ssh-stream --host root@192.168.3.88 --check-only --find-latest --machine imx6s-mcg
```

The helper validates target-side prerequisites before streaming:

- `swupdate-client` must exist on target
- `/run/swupdate/sockinstctrl` must be present as a socket
- `swupdate` service state is printed when systemd is available

### Open remote desktop profiles

```bash
remmina
```

### Set up GitHub CLI for personal + enterprise

```bash
# Authenticate personal GitHub account
gh-account login --host github.com --method web --git-protocol https --user mweitner

# Authenticate enterprise GitHub account
gh-account login --host lis-github.liebherr.com --method web --git-protocol https --user michael-weitner

# If CLI hangs after browser approval (common without desktop keyring), retry with:
gh-account login --host lis-github.liebherr.com --method web --git-protocol https --user michael-weitner --insecure-storage

# If web auth stalls, use token mode instead (token is read from prompt or GH_TOKEN)
gh-account login --host lis-github.liebherr.com --method token --git-protocol https --user michael-weitner

# If you already have enterprise credentials in ~/.netrc, use them directly
gh-account login --host lis-github.liebherr.com --method netrc --git-protocol https --user michael-weitner --insecure-storage

# Show authenticated hosts/accounts
gh-account status

# Show compact host -> users mapping
gh-account list

# Switch active user on a host
gh-account switch --host lis-github.liebherr.com --user michael-weitner
gh-account switch --host github.com --user mweitner
```

Token notes for enterprise hosts:

- Token page pattern: `https://<host>/settings/tokens`
- Example enterprise URL: `https://lis-github.liebherr.com/settings/tokens`
- If token creation is blocked by enterprise policy, use web login mode.
- `--insecure-storage` avoids keyring dependencies and stores auth in `~/.config/gh/hosts.yml`.
- `--method netrc` uses `~/.netrc` (`machine <host> ... password <token>`) as a non-interactive fallback.

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
dps-fetch-release-swu --help
dps-hawkbit-upload --help
dps-tu-reonboard --help
swupdate-ssh-stream --help
```

## References

- [Sway Documentation](https://swaywm.org/)
- [Fedora Documentation](https://docs.fedoraproject.org/)
- [Yocto Project](https://www.yoctoproject.org/)

## Release Planning

The next intended milestone is `0.1.0`, which captures the first documented Fedora-first baseline
for workstation bootstrap, development tooling, documentation, and validation.
