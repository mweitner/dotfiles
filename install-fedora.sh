#!/bin/bash
set -euo pipefail

#
# install-fedora.sh — Reproduce dotfiles on a Fedora (Minimal + Sway) install
#
# Valid for Platform: Fedora 41+
# Hardware target:    HP ZBook Power G11 (HiDPI, Wayland/Sway)
#
# Usage:
#   bash install-fedora.sh [--skip-packages] [--skip-symlinks] [--skip-services]
#
# Idempotent: safe to re-run.  All symlinks use -sf (force/overwrite).
#

SKIP_PACKAGES=false
SKIP_SYMLINKS=false
SKIP_SERVICES=false

for arg in "$@"; do
  case $arg in
    --skip-packages) SKIP_PACKAGES=true ;;
    --skip-symlinks) SKIP_SYMLINKS=true ;;
    --skip-services) SKIP_SERVICES=true ;;
  esac
done

# ── Paths ──────────────────────────────────────────────────────────────────────
DOTFILES="${DOTFILES:-$HOME/dotfiles}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

if [[ ! -d "$DOTFILES" ]]; then
  echo "ERROR: dotfiles directory not found at $DOTFILES"
  echo "Set DOTFILES or clone repo to $HOME/dotfiles"
  exit 1
fi

echo "==> Dotfiles: $DOTFILES"
echo "==> XDG_CONFIG_HOME: $XDG_CONFIG_HOME"

# ── Phase 1: Package Installation ─────────────────────────────────────────────
if [[ "$SKIP_PACKAGES" == false ]]; then
  echo ""
  echo "── Phase 1: Installing packages ─────────────────────────────────────────"
  sudo dnf install -y \
    bash-completion curl wget git pciutils usbutils

  # Wayland / Sway stack
  sudo dnf install -y \
    sway greetd greetd-selinux tuigreet \
    swaylock swayidle swaybg \
    waybar wofi \
    foot wl-clipboard \
    libnotify mako \
    brightnessctl \
    udiskie

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

  # Fonts
  sudo dnf install -y \
    google-noto-sans-fonts \
    google-noto-serif-fonts \
    google-noto-emoji-fonts \
    fontawesome-6-free-fonts \
    fontawesome-6-brands-fonts

  # Power / thermal (HP ZBook)
  sudo dnf install -y tlp tlp-rdw thermald

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
  echo "── Phase 3: Configuring greetd ──────────────────────────────────────────"
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
  echo "── Phase 3b: Power & thermal services ───────────────────────────────────"
  sudo systemctl enable --now tlp      2>/dev/null || true
  sudo systemctl enable --now thermald 2>/dev/null || true
  echo "==> tlp + thermald enabled."

  echo ""
  echo "── Phase 3c: Default shell (fish) ───────────────────────────────────────"
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
