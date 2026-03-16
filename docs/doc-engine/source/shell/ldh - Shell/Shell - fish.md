# Shell - fish

`fish` is the default interactive shell for this Fedora + Sway setup.

## Why fish for this setup

1. Better out-of-the-box UX than `bash` or `zsh` (autosuggestions, completion, helpful errors).
2. Faster path to productive shell on a fresh dev laptop.
3. Works cleanly with your `foot` + `sway` workflow.

## Install (Fedora)

```bash
sudo dnf install -y fish
```

## Set as default shell

```bash
command -v fish
grep fish /etc/shells
chsh -s "$(command -v fish)" "$USER"
```

Log out and log in again, then verify:

```bash
echo "$SHELL"
```

## Dotfiles location

Fish config is versioned here:

`fish/config.fish`

Installer symlinks it to:

`~/.config/fish/config.fish`

## Integration with Sway and foot

Your Sway keybinding already uses fish in foot:

```sh
bindsym $mod+Return exec foot -e fish
```

## Practical defaults in this repo

Current fish defaults include:

1. `fish_vi_key_bindings`
2. `EDITOR=nvim`
3. `~/.local/bin` on PATH
4. fzf integration if installed

## References

1. <https://fishshell.com/>
2. <https://fishshell.com/docs/current/tutorial.html>


\