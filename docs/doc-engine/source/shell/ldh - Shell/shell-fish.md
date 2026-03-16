# Shell - fish

`fish` is the default interactive shell for this Fedora + Sway setup.

## Why fish for this setup

1. Better out-of-the-box UX than `bash` or `zsh` (autosuggestions, completion, helpful errors).
2. Faster path to productive shell on a fresh dev laptop.
3. Works cleanly with your `foot` + `sway` workflow.

## Install (Fedora)

```bash
sudo dnf install -y fish fzf zoxide
```

If you run the repo installer, these are already covered by:

`install-fedora.sh` (Phase 1 package installation).

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

Expected value:

`/usr/bin/fish` (or equivalent fish path on your system).

## Dotfiles and symlinks

Fish config is versioned here:

`fish/config.fish`

Installer symlinks it to:

`~/.config/fish/config.fish`

Plugin list is versioned here:

`fish/fish_plugins`

Installer symlinks it to:

`~/.config/fish/fish_plugins`

If `fish/functions` or `fish/conf.d` exists in dotfiles, installer also links them.

## Plugin manager (fisher)

The installer bootstraps `fisher` and runs plugin updates automatically.

Manual fallback:

```fish
curl -fsSL https://git.io/fisher | source
fisher install jorgebucaran/fisher
fisher update
```

List installed plugins:

```fish
fisher list
```

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
4. `TERM=xterm-256color`
5. fzf integration when installed
6. zoxide integration when installed
7. git aliases (`ga`, `gc`, `gp`, `gs`, `gl`)
8. editor aliases (`vi`, `vim` -> `nvim`)
9. compact prompt with short path and mode marker (`fish/functions/fish_prompt.fish`)

## Compact prompt style

This repo uses a concise fish prompt with minimal noise:

1. No `user@host` prefix.
2. Shortened working directory path (for example: `~/p/dotfiles`).
3. Tiny vi-mode marker near cursor (`N`, `I`, `R`, `V`).
4. Exit status shown only on failure (`[1]`, `[2]`, ...).

Prompt functions are versioned here:

`fish/functions/fish_prompt.fish`

`fish/functions/fish_mode_prompt.fish`

Reload fish after changes:

```fish
exec fish
```

## Vi mode and key workflow

Fish vi mode gives modal editing on the command line.

1. `Esc` enters normal mode.
2. `i` returns to insert mode.
3. `0`, `$`, `w`, `b`, `dw`, `cw`, `x`, `p`, `u` work as expected for command-line edits.
4. `/` and `?` open the history pager (repo keybinding).

Repo key customizations in `fish/config.fish`:

1. `Ctrl-g`: clear screen and repaint prompt.
2. `Ctrl-r`: open history pager.
3. `Ctrl-k` / `Ctrl-j`: history up/down search.

Terminal copy/paste in `foot` stays terminal-driven:

1. `Ctrl-Shift-c` copy
2. `Ctrl-Shift-v` paste
3. Mouse selection + middle-click paste also works

## Daily usage examples

Search and rerun history:

```fish
# type part of a previous command and use arrows for autosuggestion/history
git sta
```

Open full history picker:

```fish
# press Ctrl-r (or / in normal mode)
```

Fast directory jumping (`zoxide`):

```fish
z proj
z dotfiles
```

Directory stack shortcuts from this repo config:

```fish
dirs -v
1   # jumps to cd +1
2   # jumps to cd +2
```

Built-in helper functions from this repo:

1. `compress <dir>` -> create `<dir>.tar.gz`
2. `wikipedia <query>`
3. `duckduckgo <query>`
4. `setupwifi [index]`

## Verify shell health

Check fish config syntax:

```bash
fish -n ~/.config/fish/config.fish
```

Check fish path and active shell:

```bash
command -v fish
echo "$SHELL"
```

## References

1. <https://fishshell.com/>
2. <https://fishshell.com/docs/current/tutorial.html>