# Diff Tooling

For a mouseless, Wayland-native developer workflow (Fedora + Sway + foot), the recommended stack is:

| Tool | Role | When to use |
|---|---|---|
| `delta` | `git diff` pager | Every day in the terminal |
| `diffview.nvim` | Full-screen diff/merge in Neovim | Git conflict resolution, PR review |
| `meld` | GUI visual diff | Comparing arbitrary files or directories |

## Install

```bash
sudo dnf install -y git-delta meld neovim
```

> `git-delta` is the package name on Fedora; the binary is called `delta`.

## Configure delta as the git pager

Add to `~/.config/git/config` (already symlinked by `install-fedora.sh`):

```ini
[core]
    pager = delta

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true        # n/N to jump between diff sections
    side-by-side = true    # widen your foot terminal first
    line-numbers = true
    syntax-theme = Dracula

[merge]
    conflictstyle = diff3

[diff]
    colorMoved = default
```

Reload with `git config --list` to verify.

## diffview.nvim (Neovim plugin)

Install via your Neovim package manager (lazy.nvim example):

```lua
{ "sindrets/diffview.nvim", dependencies = "nvim-lua/plenary.nvim" }
```

Key commands inside Neovim:

```
:DiffviewOpen          — diff working tree against HEAD
:DiffviewOpen HEAD~2   — diff last 2 commits
:DiffviewFileHistory % — history of current file
:DiffviewClose         — close the panel
```

## Meld (GUI, Wayland-native)

Meld runs natively on Wayland via GTK4. Launch from `wofi` or foot:

```bash
meld
```

To diff two directories (useful for Yocto layer comparison):

```bash
meld dir1/ dir2/
```

## Keybinding in Sway config

No sway keybinding is needed for `delta` (it is automatic via git). For a quick Meld launch:

```sh
# Add to ~/.config/sway/config if desired
bindsym $mod+Shift+d exec meld
```
