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
#   bash install-fedora-dev.sh --latest                 # install latest (no pin)
#   bash install-fedora-dev.sh --skip-mqtt-tools        # skip MQTT tools setup
#
# Idempotent: safe to re-run.
#

# ── Version pins (override via environment) ────────────────────────────────────
# Set VSCODE_VERSION to empty string to always track the latest stable release.
#
# The latest known compatible VS Code version is 1.124.2 (released 2024-06-10).
# - [VS Code 1.124 Focuses on Agent Autonomy and Parallel Sessions](https://visualstudiomagazine.com/articles/2026/06/11/vsm-vs-code-1-124.aspx#:~:text=Microsoft%20has%20released%20Visual%20Studio,added%20to%20the%20Agents%20window.)
# - [Visual Studio Code 1.124](https://code.visualstudio.com/updates/v1_124)
# - [Microsoft Build 2026 Day 2 LIVE | GitHub Copilot, VS Code, and more](https://www.youtube.com/live/xDXnWL-Mmz0)
VSCODE_VERSION="${VSCODE_VERSION:-1.124.2}"
SKIP_MQTT_TOOLS=false

for arg in "$@"; do
  case "$arg" in
    --skip-mqtt-tools) SKIP_MQTT_TOOLS=true ;;
    --latest) VSCODE_VERSION="" ;;
    *)
      echo "WARN: unknown argument '$arg' (supported: --skip-mqtt-tools, --latest); ignoring."
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
echo "── Dev: Python package manager (uv) ────────────────────────────────────"
# uv is a fast, Rust-based replacement for pip + venv. Used for Sphinx doc builds,
# Yocto Python tools, and other Python project dependency management.
# https://docs.astral.sh/uv/
if ! command -v uv >/dev/null 2>&1; then
  if curl -fsSL https://astral.sh/uv/install.sh | sh; then
    echo "==> uv installed successfully. Restart your shell or:"
    echo "    source \$HOME/.local/bin/env"
  else
    echo "WARN: uv installation failed. Install manually from https://docs.astral.sh/uv/installation/"
  fi
else
  echo "==> uv already installed: $(uv --version)"
fi

echo ""
echo "── Dev: SCM CLI tooling ────────────────────────────────────────────────"
sudo dnf install -y gh

echo ""
echo "── Dev: Hawkbit upload tooling ─────────────────────────────────────────"

is_valid_hbc_binary() {
  local candidate="$1"
  local magic

  if [[ ! -f "$candidate" ]]; then
    return 1
  fi

  magic="$(LC_ALL=C head -c 4 "$candidate" 2>/dev/null || true)"
  [[ "$magic" == $'\177ELF' ]]
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
hbc_repo_dir="$script_dir/shell"

if [[ -x /usr/local/bin/hbc ]] && is_valid_hbc_binary /usr/local/bin/hbc; then
  echo "==> hbc already installed at /usr/local/bin/hbc"
else
  hbc_source="${HBC_SOURCE:-}"
  hbc_downloaded=false
  hbc_arch=""

  case "$(uname -m)" in
    x86_64|amd64)
      hbc_arch="amd64"
      ;;
    aarch64|arm64)
      hbc_arch="arm64"
      ;;
  esac

  if [[ -z "$hbc_source" ]]; then
    for candidate in \
      "$hbc_repo_dir/hbc-${hbc_arch}-static" \
      "$hbc_repo_dir/hbc-${hbc_arch}" \
      "$HOME/.local/bin/hbc" \
      "$HOME/Downloads/hbc" \
      "$HOME/Downloads/hbc-${hbc_arch}-static" \
      "$HOME/Downloads/hbc-${hbc_arch}"; do
      if [[ -n "$candidate" && -f "$candidate" ]] && is_valid_hbc_binary "$candidate"; then
        hbc_source="$candidate"
        break
      fi
    done
  fi

  if [[ -n "$hbc_source" && -f "$hbc_source" ]] && is_valid_hbc_binary "$hbc_source"; then
    sudo install -m 0755 "$hbc_source" /usr/local/bin/hbc
    echo "==> hbc installed at /usr/local/bin/hbc"
    if [[ "$hbc_downloaded" == true ]]; then
      rm -f "$hbc_source"
    fi
  else
    echo "WARN: hbc not found locally; skipping installation."
    echo "      Upload scripts expect /usr/local/bin/hbc."
    echo "      Put the checked-in binary in ${hbc_repo_dir}/hbc-${hbc_arch}-static"
    if [[ -n "$hbc_arch" ]]; then
      echo "      Expected asset name on this machine: hbc-${hbc_arch}-static"
      echo "      Current host architecture: $(uname -m)"
    else
      echo "      Expected asset name depends on architecture; rename the downloaded binary to hbc."
    fi
    echo "      The checked-in file ${hbc_repo_dir}/hbc-arm64-static does not run on x86_64."
    echo "      Check in the matching hbc-amd64-static binary, then rerun install-fedora-dev.sh."
  fi
fi

if [[ "$SKIP_MQTT_TOOLS" == false ]]; then
  echo ""
  echo "── Dev: MQTT tooling ───────────────────────────────────────────────────"

  # On Fedora, mosquitto_pub/mosquitto_sub are bundled in the mosquitto package.
  if ! sudo dnf install -y mosquitto; then
    echo "WARN: Could not install mosquitto; skipping MQTT CLI tools."
    echo "      Please verify repo/network access and install manually: sudo dnf install mosquitto"
  fi

  # AppImages require libfuse.so.2 (FUSE2), provided by fuse-libs on Fedora.
  sudo dnf install -y fuse-libs 2>/dev/null || true

  if ! command -v mosquitto_pub >/dev/null 2>&1 || ! command -v mosquitto_sub >/dev/null 2>&1; then
    echo "WARN: mosquitto_pub/mosquitto_sub not found in PATH after install."
    echo "      On this Fedora release they may come from a differently named package."
    echo "      Try: sudo dnf search mosquitto"
  fi

  if command -v curl >/dev/null 2>&1; then
    app_dir="$HOME/.local/opt/mqtt-explorer"
    app_link="$HOME/.local/bin/mqtt-explorer"
    app_image="$app_dir/MQTT-Explorer.AppImage"
    arch="$(uname -m)"
    app_pattern='\.AppImage$'

    case "$arch" in
      x86_64|amd64)
        # x86_64 asset has no arch suffix; exclude arm/i386 variants
        app_pattern='MQTT-Explorer-[0-9]+\.[0-9]+\.[0-9]+\.AppImage$'
        ;;
      aarch64|arm64)
        app_pattern='(aarch64|arm64).*\.AppImage$'
        ;;
      armv7l|armhf)
        app_pattern='(armv7l|armhf).*\.AppImage$'
        ;;
    esac

    mkdir -p "$app_dir" "$HOME/.local/bin"

    if release_json="$(curl -fsSL https://api.github.com/repos/thomasnordquist/MQTT-Explorer/releases/latest 2>/dev/null)"; then
      app_url="$(printf '%s\n' "$release_json" \
        | grep 'browser_download_url' \
        | cut -d '"' -f4 \
        | grep -E '\.AppImage$' \
        | grep -Ei "$app_pattern" \
        | head -n1)"

      if [[ -z "$app_url" ]]; then
        app_url="$(printf '%s\n' "$release_json" | grep 'browser_download_url' | cut -d '"' -f4 | grep -E '\.AppImage$' | head -n1)"
      fi

      if [[ -n "$app_url" ]]; then
        if curl -fL "$app_url" -o "$app_image"; then
          chmod +x "$app_image"
          # Create a wrapper script instead of a symlink because:
          # 1) Fedora often lacks FUSE2 runtime for older AppImages.
          # 2) Passing --appimage-extract-and-run as a CLI arg can recurse
          #    endlessly with some AppImage runtimes.
          # 3) APPIMAGE_EXTRACT_AND_RUN=1 avoids that recursion safely.
          # 4) --no-sandbox improves compatibility with older Electron builds.
          cat > "$app_link" <<WRAPPER
#!/bin/bash
exec env APPIMAGE_EXTRACT_AND_RUN=1 "$app_image" --no-sandbox "\$@"
WRAPPER
          chmod +x "$app_link"
          echo "==> MQTT Explorer installed from official AppImage."
          echo "    Asset: $app_url"
          echo "    Start with: mqtt-explorer"
          echo "    Alternative: APPIMAGE_EXTRACT_AND_RUN=1 $app_image --no-sandbox"
          echo "    If command is missing, ensure ~/.local/bin is in PATH."
          echo "    Note: If first launch shows a React error dialog, use MQTT Explorer's"
          echo "          in-app fresh-start/reset button once, then restart the app."
        else
          echo "WARN: Failed to download MQTT Explorer AppImage."
        fi
      else
        echo "WARN: Could not find an AppImage asset in latest MQTT Explorer release metadata."
      fi
    else
      echo "WARN: Could not query MQTT Explorer releases from GitHub (network/proxy/SSL issue)."
      echo "      Manual fallback: https://github.com/thomasnordquist/MQTT-Explorer/releases"
    fi
  else
    echo "WARN: curl is not available; skipping MQTT Explorer AppImage installation."
    echo "      Install curl or download manually from:"
    echo "      https://github.com/thomasnordquist/MQTT-Explorer/releases"
  fi
else
  echo ""
  echo "── Dev: MQTT tooling (skipped) ─────────────────────────────────────────"
  echo "INFO: Skipping mosquitto/mosquitto-clients/MQTT Explorer AppImage (--skip-mqtt-tools)."
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

echo ""
echo "── Dev: Bluetooth helper scripts ───────────────────────────────────────"
# Install bluetooth helper script from this repo if present
bluetooth_src="$script_dir/shell/bluetooth-devices"
install_dir="$HOME/.local/bin"
if [[ -f "$bluetooth_src" ]]; then
  mkdir -p "$install_dir"
  ln -sfn "$bluetooth_src" "$install_dir/bluetooth-devices"
  chmod +x "$install_dir/bluetooth-devices" 2>/dev/null || true
  # Create convenience command names that point to the single helper
  for cmd in connect-airpods connect-mouse connect-keyboard bt-show; do
    ln -sfn "$install_dir/bluetooth-devices" "$install_dir/$cmd"
  done
  echo "==> Bluetooth helper installed to $install_dir (connect-airpods, connect-mouse, connect-keyboard)"
else
  echo "INFO: $bluetooth_src not found; skipping bluetooth helper installation."
  echo "      To install: place the helper at $bluetooth_src and rerun this script."
fi

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
  # Remove version lock if it exists (from previous pinned installs)
  sudo dnf versionlock delete code 2>/dev/null || true
  
  # Upgrade to latest (dnf upgrade installs if not present, upgrades if already installed)
  sudo dnf upgrade -y code
  echo "==> VS Code upgraded to latest (no version pin)."
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
echo "── Dev: Home Office VPN & GitHub Controller access ──────────────────────"
echo ""
echo "When working from home with Liebherr VPN, use fix-vpn-dns-browser to"
echo "resolve corporate GitHub Controller API endpoints correctly."
echo ""
echo "After VPN connect:"
echo "  fix-vpn-dns-browser        # Fix DNS + browser cache"
echo "  test-vpn-dns               # Verify OS DNS resolution"
echo "  test-browser-dns           # Verify HTTPS connectivity"
echo ""
echo "See wiki docs for full details:"
echo "  ~/document/wiki/doc-engine/source/analysis/homeoffice-github-controller-access/"
echo ""

echo ""
echo "==> Dev tools installed."
