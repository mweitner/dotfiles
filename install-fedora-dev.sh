#!/bin/bash
set -euo pipefail

#
# install-fedora-dev.sh — Development tooling for Fedora (Minimal + Sway)
#
# Called automatically from install-fedora.sh, or run standalone to set up or
# upgrade development tools independently of the base system.
#
# Version-sensitive apps are pinned here and upgraded deliberately:
#
#   VSCODE_VERSION=1.116 bash install-fedora-dev.sh    # bump VS Code pin
#   VSCODE_VERSION=""    bash install-fedora-dev.sh    # install latest (no pin)
#
# Idempotent: safe to re-run.
#

# ── Version pins (override via environment) ────────────────────────────────────
# Set VSCODE_VERSION to empty string to always track the latest stable release.
VSCODE_VERSION="${VSCODE_VERSION:-1.115}"

echo ""
echo "── Dev: Editors & diff tooling ─────────────────────────────────────────"
sudo dnf install -y \
  neovim \
  git-delta \
  meld

echo ""
echo "── Dev: Languages ───────────────────────────────────────────────────────"
sudo dnf install -y golang

echo ""
echo "── Dev: Git hooks ───────────────────────────────────────────────────────"
sudo dnf install -y pre-commit

echo ""
echo "── Dev: Yocto host build dependencies ──────────────────────────────────"
# Tools commonly absent on minimal Fedora installs that Yocto requires at build time.
sudo dnf install -y \
  gawk diffstat chrpath rpcgen texinfo socat \
  perl perl-Data-Dumper perl-Thread-Queue perl-Text-ParseWords

echo ""
echo "── Dev: VS Code ${VSCODE_VERSION:-(latest)} ─────────────────────────────────────────────────────"

# Import Microsoft GPG key — rpm --import is idempotent (no-op if key already exists).
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

# Write official VS Code Fedora .repo file (tee overwrite keeps it current on re-run).
sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'REPOEOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPOEOF

# Refresh metadata; check-update exits non-zero when pending updates exist — suppress.
sudo dnf check-update || true

if [[ -n "${VSCODE_VERSION}" ]]; then
  # Clear any existing versionlock so the new pin can be applied cleanly on re-run.
  sudo dnf versionlock delete code 2>/dev/null || true

  # "code-1.115*" is passed literally to dnf (inside double quotes → no shell glob).
  # dnf resolves the trailing wildcard against its package database, picking the
  # highest matching release (e.g. 1.115.0, 1.115.1, …).
  if sudo dnf install -y "code-${VSCODE_VERSION}*"; then
    echo "==> VS Code ${VSCODE_VERSION} installed (pinned)."
  else
    echo "WARN: code-${VSCODE_VERSION}* not found in repo; falling back to latest."
    sudo dnf install -y code
  fi

  # Lock the installed version to prevent silent upgrades via dnf upgrade.
  # dnf4: needs python3-dnf-plugin-versionlock; dnf5 (Fedora 41+): built-in.
  sudo dnf install -y python3-dnf-plugin-versionlock 2>/dev/null || true
  if sudo dnf versionlock add code 2>/dev/null; then
    echo "==> VS Code ${VSCODE_VERSION} version-locked."
    echo "    To upgrade: sudo dnf versionlock delete code"
    echo "                VSCODE_VERSION=x.y bash install-fedora-dev.sh"
  else
    echo "INFO: versionlock unavailable — track VS Code upgrades manually."
  fi
else
  sudo dnf install -y code
  echo "==> VS Code latest installed (no version pin)."
fi

echo ""
echo "==> Dev tools installed."
