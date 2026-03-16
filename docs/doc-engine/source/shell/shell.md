# Shell Interpreter

Linux Development Host > Shell

This guide defines the default shell setup for Fedora + Sway.

## Decision

Primary setup:

1. Terminal emulator: `foot`
2. Interactive shell: `fish`
3. Login/display stack: `greetd + tuigreet + sway`

Why this combination:

1. `fish` has excellent defaults (autosuggestions, completion, discoverability).
2. `foot` is fast, Wayland-native, and works well on HiDPI.
3. Works cleanly with your existing Sway config (`$mod+Return` opens `foot -e fish`).

## Reproducible Setup

Run from your dotfiles repo root:

```bash
bash ./install-fedora.sh
```

This script installs packages, links config files, enables services, and tries to set `fish` as your default login shell.

## Verify

```bash
echo "$SHELL"
which fish
which foot
```

Expected:

1. `echo $SHELL` returns `/usr/bin/fish` after re-login.
2. `fish` and `foot` are installed.

## Manual fallback (if needed)

If `chsh` failed in the install script, run manually:

```bash
chsh -s "$(command -v fish)" "$USER"
```

Then log out and log in again.

## Related Pages

1. `docs/doc-engine/source/shell/ldh - Shell/Shell - fish.md`
2. `docs/doc-engine/source/window-manager/sway/take-screenshot.md`
3. `docs/doc-engine/source/window-manager/sway/diff.md`