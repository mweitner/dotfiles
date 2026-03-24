#!/bin/bash
set -euo pipefail

#
# install-fedora.sh — Reproduce dotfiles on a Fedora (Minimal + Sway) install
#
# Valid for Platform: Fedora 41+
# Hardware target:    HP ZBook Power G11 (HiDPI, Wayland/Sway)
#
# Usage:
#   bash install-fedora.sh [--skip-packages] [--skip-symlinks] [--skip-services] [--with-ssh-secrets]
#
# Idempotent: safe to re-run.  All symlinks use -sf (force/overwrite).
#

SKIP_PACKAGES=false
SKIP_SYMLINKS=false
SKIP_SERVICES=false
WITH_SSH_SECRETS=false

for arg in "$@"; do
  case $arg in
    --skip-packages) SKIP_PACKAGES=true ;;
    --skip-symlinks) SKIP_SYMLINKS=true ;;
    --skip-services) SKIP_SERVICES=true ;;
    --with-ssh-secrets) WITH_SSH_SECRETS=true ;;
  esac
done

# ── Paths ──────────────────────────────────────────────────────────────────────
DOTFILES="${DOTFILES:-$HOME/dotfiles}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DEFAULT_BROWSER="${DEFAULT_BROWSER:-google-chrome.desktop}"

if [[ ! -d "$DOTFILES" ]]; then
  echo "ERROR: dotfiles directory not found at $DOTFILES"
  echo "Set DOTFILES or clone repo to $HOME/dotfiles"
  exit 1
fi

# Pick an installed browser desktop file and register it as default.
set_default_browser() {
  local app
  local candidates=()
  local fallback=(
    google-chrome.desktop
    firefox.desktop
    qutebrowser.desktop
    org.chromium.Chromium.desktop
    chromium-browser.desktop
  )

  if ! command -v xdg-settings >/dev/null 2>&1 || ! command -v xdg-mime >/dev/null 2>&1; then
    echo "WARN: xdg-settings/xdg-mime not available; skipping default browser setup."
    return 0
  fi

  # User-selected default first, then fallback list.
  candidates+=("$DEFAULT_BROWSER")
  for app in "${fallback[@]}"; do
    if [[ "$app" != "$DEFAULT_BROWSER" ]]; then
      candidates+=("$app")
    fi
  done

  for app in "${candidates[@]}"; do
    if [[ -f "/usr/share/applications/$app" || -f "$HOME/.local/share/applications/$app" ]]; then
      xdg-settings set default-web-browser "$app" || true
      xdg-mime default "$app" x-scheme-handler/http || true
      xdg-mime default "$app" x-scheme-handler/https || true
      xdg-mime default "$app" text/html || true
      xdg-mime default "$app" application/xhtml+xml || true
      echo "==> Default browser set to $app"
      return 0
    fi
  done

  echo "WARN: no known browser desktop file found; leaving default browser unchanged."
}

# Install optional company CA certs from a private secrets directory.
# Expected filenames:
# - LiebherrEnterpriseCA02.crt
# - LiebherrRootCA2.crt
install_company_ca_certs() {
  local cert anchors_dir secrets_dir
  local -a certs=(
    LiebherrEnterpriseCA02.crt
    LiebherrRootCA2.crt
  )
  local -a candidate_dirs=(
    "$DOTFILES/.secrets"
    "$DOTFILES/.secret"
  )

  anchors_dir="/etc/pki/ca-trust/source/anchors"
  secrets_dir=""

  for cert in "${candidate_dirs[@]}"; do
    if [[ -d "$cert" ]]; then
      secrets_dir="$cert"
      break
    fi
  done

  if [[ -z "$secrets_dir" ]]; then
    echo "WARN: no secrets dir found at $DOTFILES/.secrets (or .secret); skipping company CA install."
    return 0
  fi

  sudo mkdir -p "$anchors_dir"

  local copied_any=false
  for cert in "${certs[@]}"; do
    if [[ -f "$secrets_dir/$cert" ]]; then
      sudo install -m 0644 "$secrets_dir/$cert" "$anchors_dir/$cert"
      copied_any=true
    else
      echo "WARN: missing cert $secrets_dir/$cert"
    fi
  done

  if [[ "$copied_any" == true ]]; then
    sudo update-ca-trust extract
    echo "==> Company CA certificates installed into Fedora trust store."
  else
    echo "WARN: no company CA certificates copied; trust store unchanged."
  fi
}

# Install SSH profile for this machine from secrets.
# Source: $DOTFILES/.secrets/ssh/dev-pc/.ssh
# Strategy: copy files (not symlink) so ~/.ssh remains independent and can be
# permission-hardened for OpenSSH strict checks.
install_ssh_secrets_dev_pc() {
  local src dst
  src="$DOTFILES/.secrets/ssh/dev-pc/.ssh"
  dst="$HOME/.ssh"

  if [[ ! -d "$src" ]]; then
    echo "WARN: SSH secrets source not found at $src; skipping SSH setup."
    return 0
  fi

  mkdir -p "$dst"
  cp -a "$src"/. "$dst"/

  # OpenSSH requires strict permissions for private keys and config.
  chmod 700 "$dst"
  find "$dst" -type d -exec chmod 700 {} +
  find "$dst" -type f -exec chmod 600 {} +
  find "$dst" -type f -name "*.pub" -exec chmod 644 {} +
  [[ -f "$dst/known_hosts" ]] && chmod 644 "$dst/known_hosts"
  [[ -f "$dst/known_hosts.old" ]] && chmod 644 "$dst/known_hosts.old"

  # Keep ownership correct even if files were previously created by root.
  chown -R "$USER:$USER" "$dst" 2>/dev/null || sudo chown -R "$USER:$USER" "$dst" 2>/dev/null || true

  echo "==> SSH profile installed from $src to $dst with hardened permissions."
}

echo "==> Dotfiles: $DOTFILES"
echo "==> XDG_CONFIG_HOME: $XDG_CONFIG_HOME"

# ── Phase 1: Package Installation ─────────────────────────────────────────────
if [[ "$SKIP_PACKAGES" == false ]]; then
  echo ""
  echo "── Phase 1: Installing packages ─────────────────────────────────────────"
  sudo dnf install -y \
    bash-completion curl wget git pciutils usbutils xdg-utils \
    NetworkManager NetworkManager-tui iwd

  # NM GUI tools naming differs by Fedora release. Prefer legacy meta package,
  # then fallback to split packages used on newer Fedora versions.
  if ! sudo dnf install -y NetworkManager-gnome; then
    sudo dnf install -y network-manager-applet nm-connection-editor
  fi

  # Wayland / Sway stack
  sudo dnf install -y \
    sway greetd greetd-selinux tuigreet \
    swaylock swayidle swaybg \
    xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr \
    waybar wofi \
    foot wl-clipboard \
    libnotify mako \
    brightnessctl \
    udiskie \
    kanshi

  # Screenshot tooling
  # requires sway stack packages wl-clipboard libnotify
  # ImageMagick provides both magick and convert used by lock.sh blur step
  sudo dnf install -y grim slurp ImageMagick

  # Diff tooling
  sudo dnf install -y \
    git-delta \
    meld \
    neovim

  # Audio mixer (PipeWire-compatible via pipewire-pulseaudio)
  sudo dnf install -y pavucontrol

  # Shell & multiplexer
  sudo dnf install -y zsh fish tmux tmuxp

  # Serial port terminal (tio)
  sudo dnf install -y tio

  # Modern CLI tools
  sudo dnf install -y ripgrep fd-find fzf zoxide htop btop

  # NAS/SMB client tools
  sudo dnf install -y cifs-utils

  # Fonts
  sudo dnf install -y \
    google-noto-sans-fonts \
    google-noto-serif-fonts \
    google-noto-emoji-fonts \
    fontawesome-6-free-fonts \
    fontawesome-6-brands-fonts

  # VPN client — preferred: gpclient (yuezk COPR) for GlobalProtect SAML
  # Fallback: raw openconnect when COPR is unavailable
  if sudo dnf copr enable -y yuezk/globalprotect-openconnect 2>/dev/null; then
    sudo dnf install -y globalprotect-openconnect
    echo "==> gpclient installed from yuezk COPR (preferred GlobalProtect backend)."
  else
    echo "WARN: yuezk COPR not reachable; falling back to openconnect only."
  fi
  # openconnect kept as fallback runtime dependency used by vpn-on
  sudo dnf install -y openconnect vpnc-script

  # Remote desktop client — Remmina + RDP plugin (for Windows/hop-PC access over VPN)
  sudo dnf install -y remmina remmina-plugins-rdp remmina-plugins-secret

  # Secret service backend for Remmina credential storage in Sway sessions
  sudo dnf install -y gnome-keyring libsecret

  # Power / thermal (HP ZBook)
  sudo dnf install -y tlp tlp-rdw thermald

  # Thunderbolt device manager — auto-authorizes docks (Dell WD19TB needs this for USB)
  sudo dnf install -y bolt

  echo "==> Packages installed."
fi

# ── Phase 2: Symlinks ──────────────────────────────────────────────────────────
if [[ "$SKIP_SYMLINKS" == false ]]; then
  echo ""
  echo "── Phase 2: Creating config symlinks ────────────────────────────────────"

  # Sway
  mkdir -p "$XDG_CONFIG_HOME/sway"
  ln -sf "$DOTFILES/sway/config"   "$XDG_CONFIG_HOME/sway/config"
  # Link entire scripts directory so grimshot.sh and future scripts are available
  rm -rf "$XDG_CONFIG_HOME/sway/scripts"
  ln -sf "$DOTFILES/sway/scripts"  "$XDG_CONFIG_HOME/sway/scripts"

  # Display management (kanshi for multi-monitor hotplug + profile switching)
  mkdir -p "$XDG_CONFIG_HOME/kanshi"
  [[ -f "$DOTFILES/.config/kanshi/config" ]] && ln -sf "$DOTFILES/.config/kanshi/config" "$XDG_CONFIG_HOME/kanshi/config"

  # Network interface naming policy (prefer enx<mac> for USB Realtek NICs)
  # Managed via systemd .link file in /etc/systemd/network.
  if [[ -f "$DOTFILES/systemd/network/10-usb-ethernet-enx.link" ]]; then
    sudo mkdir -p /etc/systemd/network
    sudo ln -sfn "$DOTFILES/systemd/network/10-usb-ethernet-enx.link" /etc/systemd/network/10-usb-ethernet-enx.link
  fi

  # i3 scripts reused by sway config (lock, load-default-ws, etc.)
  rm -rf "$XDG_CONFIG_HOME/i3"
  ln -sf "$DOTFILES/i3" "$XDG_CONFIG_HOME"

  # i3/feh wallpaper (referenced in sway config exec_always swaybg ...)
  # wallpaper lives in dotfiles/i3/feh/ — already covered by the i3 symlink above

  # Waybar
  mkdir -p "$XDG_CONFIG_HOME/waybar"
  ln -sf "$DOTFILES/waybar/config.jsonc" "$XDG_CONFIG_HOME/waybar/config.jsonc"
  # style.css is optional — only link if it exists in the repo
  [[ -f "$DOTFILES/waybar/style.css" ]] && \
    ln -sf "$DOTFILES/waybar/style.css" "$XDG_CONFIG_HOME/waybar/style.css"

  # Mako (Wayland-native notification daemon)
  mkdir -p "$XDG_CONFIG_HOME/mako"
  [[ -f "$DOTFILES/mako/config" ]] && \
    ln -sf "$DOTFILES/mako/config" "$XDG_CONFIG_HOME/mako/config"

  # Remove dunst (X11 notification daemon — replaced by mako on Wayland)
  sudo dnf remove -y dunst 2>/dev/null || true
  rm -rf "$XDG_CONFIG_HOME/dunst"

  # Foot terminal
  mkdir -p "$XDG_CONFIG_HOME/foot"
  [[ -f "$DOTFILES/foot/foot.ini" ]] && \
    ln -sf "$DOTFILES/foot/foot.ini" "$XDG_CONFIG_HOME/foot/foot.ini"

  # fish shell
  mkdir -p "$XDG_CONFIG_HOME/fish"
  [[ -f "$DOTFILES/fish/config.fish" ]] && \
    ln -sf "$DOTFILES/fish/config.fish" "$XDG_CONFIG_HOME/fish/config.fish"
  if [[ -d "$DOTFILES/fish/conf.d" ]]; then
    rm -rf "$XDG_CONFIG_HOME/fish/conf.d"
    ln -sf "$DOTFILES/fish/conf.d" "$XDG_CONFIG_HOME/fish/conf.d"
  fi
  if [[ -d "$DOTFILES/fish/functions" ]]; then
    rm -rf "$XDG_CONFIG_HOME/fish/functions"
    ln -sf "$DOTFILES/fish/functions" "$XDG_CONFIG_HOME/fish/functions"
  fi
  [[ -f "$DOTFILES/fish/fish_plugins" ]] && \
    ln -sf "$DOTFILES/fish/fish_plugins" "$XDG_CONFIG_HOME/fish/fish_plugins"

  # local user scripts (used by launchers like wofi run)
  mkdir -p "$HOME/.local/bin"
  [[ -f "$DOTFILES/shell/nmtui" ]] && ln -sf "$DOTFILES/shell/nmtui" "$HOME/.local/bin/nmtui"
  [[ -f "$DOTFILES/shell/vpn-on" ]] && ln -sf "$DOTFILES/shell/vpn-on" "$HOME/.local/bin/vpn-on"
  [[ -f "$DOTFILES/shell/rdp-hop" ]] && ln -sf "$DOTFILES/shell/rdp-hop" "$HOME/.local/bin/rdp-hop"
  [[ -f "$DOTFILES/shell/setup-ugreen-nas-mount" ]] && ln -sf "$DOTFILES/shell/setup-ugreen-nas-mount" "$HOME/.local/bin/setup-ugreen-nas-mount"
  [[ -f "$DOTFILES/shell/nas-status" ]] && ln -sf "$DOTFILES/shell/nas-status" "$HOME/.local/bin/nas-status"
  [[ -f "$DOTFILES/shell/setup-machine-network-profiles.sh" ]] && ln -sf "$DOTFILES/shell/setup-machine-network-profiles.sh" "$HOME/.local/bin/setup-machine-network-profiles"
  [[ -f "$DOTFILES/shell/setup-adapters.sh" ]] && ln -sf "$DOTFILES/shell/setup-adapters.sh" "$HOME/.local/bin/setup-adapters"

  # X11 monitor scripts (referenced by sway mode_display)
  rm -rf "$XDG_CONFIG_HOME/X11"
  ln -sf "$DOTFILES/X11" "$XDG_CONFIG_HOME"

  # zsh
  mkdir -p "$XDG_CONFIG_HOME/zsh"
  [[ -f "$DOTFILES/zsh/.zshenv" ]] && ln -sf "$DOTFILES/zsh/.zshenv" "$HOME"
  [[ -f "$DOTFILES/zsh/.zshrc"  ]] && ln -sf "$DOTFILES/zsh/.zshrc"  "$XDG_CONFIG_HOME/zsh"
  ln -sf "$DOTFILES/zsh/aliases" "$XDG_CONFIG_HOME/zsh/aliases"
  rm -rf "$XDG_CONFIG_HOME/zsh/external"
  ln -sf "$DOTFILES/zsh/external" "$XDG_CONFIG_HOME/zsh/external"

  # git
  mkdir -p "$XDG_CONFIG_HOME/git"
  ln -sf "$DOTFILES/git/config" "$XDG_CONFIG_HOME/git/config"

  # tmux / tmuxp
  mkdir -p "$XDG_CONFIG_HOME/tmux"
  ln -sf "$DOTFILES/tmux/tmux.conf" "$XDG_CONFIG_HOME/tmux/tmux.conf"
  rm -rf "$XDG_CONFIG_HOME/tmuxp"
  ln -sf "$DOTFILES/tmuxp" "$XDG_CONFIG_HOME/tmuxp"

  # qutebrowser
  mkdir -p "$XDG_CONFIG_HOME/qutebrowser"
  [[ -f "$DOTFILES/qutebrowser/config.py" ]] && \
    ln -sf "$DOTFILES/qutebrowser/config.py" "$XDG_CONFIG_HOME/qutebrowser/config.py"

  # Fonts
  mkdir -p "$XDG_DATA_HOME"
  cp -rf "$DOTFILES/fonts" "$XDG_DATA_HOME"

  echo "==> Symlinks created."
fi

# ── Phase 3: greetd (display manager) ─────────────────────────────────────────
if [[ "$SKIP_SERVICES" == false ]]; then
  echo ""
  echo "── Phase 3a: NetworkManager + iwd ───────────────────────────────────────"
  sudo mkdir -p /etc/NetworkManager/conf.d
  sudo tee /etc/NetworkManager/conf.d/10-wifi-backend.conf >/dev/null <<'EOF'
[device]
wifi.backend=iwd
EOF

  sudo systemctl enable --now iwd 2>/dev/null || true
  sudo systemctl stop wpa_supplicant.service 2>/dev/null || true
  sudo systemctl disable wpa_supplicant.service 2>/dev/null || true
  sudo systemctl enable --now NetworkManager
  sudo systemctl restart NetworkManager
  echo "==> NetworkManager configured with iwd backend."
  echo "==> NetworkManager GUI tools available: nm-applet, nm-connection-editor."

  echo ""
  echo "── Phase 3b: Configuring greetd ──────────────────────────────────────────"
  if command -v tuigreet &>/dev/null; then
    GREETD_DOTFILE="$DOTFILES/greetd/config.toml"
    sudo mkdir -p /etc/greetd

    if [[ -f "$GREETD_DOTFILE" ]]; then
      sudo ln -sfn "$GREETD_DOTFILE" /etc/greetd/config.toml
    else
      echo "WARN: $GREETD_DOTFILE not found, writing fallback /etc/greetd/config.toml"
      sudo tee /etc/greetd/config.toml > /dev/null <<'EOF'
[terminal]
vt = 1

[default_session]
command = "/usr/bin/tuigreet --time --remember --asterisks --cmd sway"
user = "greetd"
EOF
    fi
    sudo chown greetd:greetd /var/lib/greetd

    # Fedora may report "preset: disabled" for greetd; explicitly enable it.
    sudo systemctl set-default graphical.target
    sudo systemctl unmask greetd.service
    sudo systemctl enable greetd.service
    # Note: don't start greetd immediately, as it may interfere with the current session.
    #sudo systemctl start greetd.service

    if sudo systemctl is-enabled greetd.service >/dev/null && \
       sudo systemctl is-active greetd.service >/dev/null; then
      echo "==> greetd configured, enabled, and active."
    else
      echo "WARN: greetd is not fully active. Check with: systemctl status greetd"
    fi
  else
    echo "WARN: tuigreet not found — skipping greetd config (did package install run?)"
  fi

  echo ""
  echo "── Phase 3c: Power & thermal services ───────────────────────────────────"
  sudo systemctl enable --now tlp      2>/dev/null || true
  sudo systemctl enable --now thermald 2>/dev/null || true
  echo "==> tlp + thermald enabled."

  echo ""
  echo "── Phase 3c1: Serial console permissions (tio) ──────────────────────────"
  # USB serial adapters are commonly owned by group dialout on Fedora.
  # Grant access so tools like tio can open /dev/ttyUSB* without sudo.
  if getent group dialout >/dev/null; then
    sudo usermod -aG dialout "$USER" 2>/dev/null || true
  fi
  # Some setups/tools also rely on lock group for serial lock files.
  if getent group lock >/dev/null; then
    sudo usermod -aG lock "$USER" 2>/dev/null || true
  fi
  echo "==> Added $USER to serial access groups (dialout/lock when available)."
  echo "   Re-login required for group membership changes to take effect."

  echo ""
  echo "── Phase 3c2: Thunderbolt authorization (bolt) ──────────────────────────"
  # bolt is socket/dbus-activated on Fedora (static unit), so start is enough.
  sudo systemctl start bolt 2>/dev/null || true
  # Enroll the Dell WD19TB dock if it is currently connected and not yet enrolled.
  # bolt enrolls by UUID; skip silently if not connected or already enrolled.
  if command -v boltctl &>/dev/null; then
    DOCK_UUID="$(boltctl list 2>/dev/null | awk '/Dell WD19TB/{found=1} found && /uuid/{print $2; exit}')"
    if [[ -n "$DOCK_UUID" ]]; then
      # "stored:" appears in boltctl list output only when the device is enrolled
      if boltctl list 2>/dev/null | awk "/uuid.*$DOCK_UUID/{found=1} found && /stored:/{print; exit}" | grep -q "stored:"; then
        echo "==> Dell WD19TB dock already enrolled (UUID: $DOCK_UUID)."
      else
        sudo boltctl enroll --policy auto "$DOCK_UUID" 2>/dev/null && \
          echo "==> Dell WD19TB dock enrolled (UUID: $DOCK_UUID)." || \
          echo "WARN: boltctl enroll failed — enroll manually with: sudo boltctl enroll --policy auto <uuid>"
      fi
    else
      echo "INFO: Dell WD19TB dock not connected — skipping enroll."
      echo "      When connected, run: sudo boltctl enroll --policy auto <uuid>"
      echo "      Or re-run this script with the dock plugged in."
    fi
  fi
  echo "==> bolt (Thunderbolt manager) enabled."

  echo ""
  echo "── Phase 3d: Default shell (fish) ───────────────────────────────────────"
  if command -v fish &>/dev/null; then
    FISH_PATH="$(command -v fish)"
    if [[ "${SHELL:-}" != "$FISH_PATH" ]]; then
      if grep -q "^$FISH_PATH$" /etc/shells; then
        chsh -s "$FISH_PATH" "$USER" || \
          echo "WARN: could not set fish as default shell automatically."
      else
        echo "WARN: $FISH_PATH is not listed in /etc/shells"
      fi
    fi
    echo "==> fish default shell check done."

    # Bootstrap fish plugin manager + plugins declared in fish_plugins.
    if [[ -f "$XDG_CONFIG_HOME/fish/fish_plugins" ]]; then
      if fish -c 'functions -q fisher' >/dev/null 2>&1; then
        fish -c 'fisher update' || echo "WARN: fisher update failed."
      else
        fish -c 'curl -fsSL https://git.io/fisher | source; and fisher install jorgebucaran/fisher; and fisher update' || \
          echo "WARN: fisher bootstrap failed (network or plugin source issue)."
      fi
      echo "==> fish plugins checked (fisher)."
    fi
  else
    echo "WARN: fish not found."
  fi

  echo ""
  echo "── Phase 3e: Default browser ────────────────────────────────────────────"
  set_default_browser

  echo ""
  echo "── Phase 3f: Company CA certificates ────────────────────────────────────"
  install_company_ca_certs

  echo ""
  echo "── Phase 3g: SSH profile (dev-pc secrets) ───────────────────────────────"
  if [[ "$WITH_SSH_SECRETS" == true ]]; then
    install_ssh_secrets_dev_pc
  else
    echo "INFO: SSH profile install skipped (opt-in)."
    echo "      Re-run with --with-ssh-secrets to install from .secrets/ssh/dev-pc/.ssh"
  fi
fi

# ── Phase 4: Yocto shared directory ───────────────────────────────────────────
echo ""
echo "── Phase 4: Yocto shared sstate/downloads dirs ──────────────────────────"
sudo mkdir -p /opt/yocto/shared/downloads
sudo mkdir -p /opt/yocto/shared/sstate-cache
sudo chown -R "$USER:$USER" /opt/yocto
sudo chmod -R 775 /opt/yocto
# Disable copy-on-write for large build caches (Btrfs only)
if findmnt -n -o FSTYPE / | grep -q btrfs; then
  sudo chattr +C /opt/yocto/shared/downloads    2>/dev/null || true
  sudo chattr +C /opt/yocto/shared/sstate-cache 2>/dev/null || true
fi
echo "==> Yocto directories ready."

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo "✔  install-fedora.sh complete."
echo "   Reboot (or run 'sway') to start the Wayland session."
