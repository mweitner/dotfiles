
# Sway Setup Notes

This page tracks the most important Sway integration points for the Fedora dev PC.

## Terminal + Shell

Primary terminal and shell:

1. Terminal: `foot`
2. Shell: `fish`

Keybinding in `sway/config`:

```sh
bindsym $mod+Return exec foot -e fish
```

## Supporting Docs

1. Screenshot tooling: `docs/doc-engine/source/window-manager/sway/take-screenshot.md`
2. Diff tooling: `docs/doc-engine/source/window-manager/sway/diff.md`
3. Shell runbook: `docs/doc-engine/source/shell/shell.md`

## Reproducible Install

Run from the dotfiles repository root:

```bash
bash ./install-fedora.sh
```

The installer sets up package dependencies, symlinks, services, and shell defaults used by this Sway configuration.
