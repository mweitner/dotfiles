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
#   bash install-fedora-dev.sh --skip-mqtt-tools        # skip MQTT tools setup
#
# Idempotent: safe to re-run.
#

# ── Version pins (override via environment) ────────────────────────────────────
# Set VSCODE_VERSION to empty string to always track the latest stable release.
VSCODE_VERSION="${VSCODE_VERSION:-1.115}"
SKIP_MQTT_TOOLS=false

for arg in "$@"; do
  case "$arg" in
    --skip-mqtt-tools) SKIP_MQTT_TOOLS=true ;;
    *)
      echo "WARN: unknown argument '$arg' (supported: --skip-mqtt-tools); ignoring."
      ;;
  esac
done

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
echo "── Dev: Documentation tools ─────────────────────────────────────────────"
sudo dnf install -y \
  plantuml \
  pandoc

echo ""
echo "── Dev: Git hooks ───────────────────────────────────────────────────────"
sudo dnf install -y pre-commit

echo ""
echo "── Dev: SCM CLI tooling ────────────────────────────────────────────────"
sudo dnf install -y gh

if [[ "$SKIP_MQTT_TOOLS" == false ]]; then
  echo ""
  echo "── Dev: MQTT tooling ───────────────────────────────────────────────────"

  if ! sudo dnf install -y mosquitto mosquitto-clients flatpak; then
    echo "WARN: Could not install mosquitto-clients (package name differs on some Fedora releases)."
    echo "      Retrying with mosquitto + flatpak only."
    if ! sudo dnf install -y mosquitto flatpak; then
      echo "WARN: MQTT base packages could not be installed; skipping MQTT Explorer installation."
      echo "      Please verify repo/network access and install manually later."
    fi
  fi

  if ! command -v mosquitto_pub >/dev/null 2>&1 || ! command -v mosquitto_sub >/dev/null 2>&1; then
    echo "WARN: mosquitto_pub/mosquitto_sub not found in PATH after install."
    echo "      On this Fedora release they may come from a differently named package."
    echo "      Try: sudo dnf search mosquitto"
  fi

  if command -v flatpak >/dev/null 2>&1; then
    if ! flatpak remotes --columns=name | grep -qx flathub; then
      if flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
        echo "==> Flathub remote added."
      else
        echo "WARN: Could not add Flathub remote; skipping MQTT Explorer installation."
      fi
    fi

    if flatpak remote-info flathub com.github.thomasnordquist.MQTTExplorer >/dev/null 2>&1; then
      if flatpak install -y flathub com.github.thomasnordquist.MQTTExplorer; then
        echo "==> MQTT Explorer installed via Flatpak (Flathub)."
      else
        echo "WARN: MQTT Explorer installation failed. Install manually later with:"
        echo "      flatpak install flathub com.github.thomasnordquist.MQTTExplorer"
      fi
    else
      echo "WARN: MQTT Explorer app id not found on Flathub metadata."
      echo "      Run 'flatpak search mqtt explorer' and install the matching id manually."
    fi
  fi
else
  echo ""
  echo "── Dev: MQTT tooling (skipped) ─────────────────────────────────────────"
  echo "INFO: Skipping mosquitto/mosquitto-clients/MQTT Explorer (--skip-mqtt-tools)."
fi

echo ""
echo "── Dev: 1Password app + CLI ────────────────────────────────────────────"
if sudo rpm --import https://downloads.1password.com/linux/keys/1password.asc; then
  sudo tee /etc/yum.repos.d/1password.repo >/dev/null <<'REPOEOF'
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://downloads.1password.com/linux/keys/1password.asc
REPOEOF

  if sudo dnf install -y 1password 1password-cli; then
    echo "==> 1Password desktop app and CLI installed."
  else
    echo "WARN: Could not install 1password packages from official repo."
    echo "      Verify network/CA access and rerun install-fedora-dev.sh."
  fi
else
  echo "WARN: Could not import 1Password GPG key; skipping 1Password package installation."
fi

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
echo "── Dev: Azure CLI ───────────────────────────────────────────────────────"
# Microsoft GPG key was already imported above for VS Code — rpm --import is idempotent.
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

sudo tee /etc/yum.repos.d/azure-cli.repo >/dev/null <<'REPOEOF'
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPOEOF

if sudo dnf install -y azure-cli; then
  echo "==> Azure CLI installed."
  echo "    Login:        az login"
  echo "    Device flow:  az login --use-device-code"
  echo "    Graph token:  az account get-access-token --resource-type ms-graph --query accessToken -o tsv"
else
  echo "WARN: Azure CLI install failed. Check network/CA access and rerun."
fi

echo ""
echo "==> Dev tools installed."
