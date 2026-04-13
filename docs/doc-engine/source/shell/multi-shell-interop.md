# Multi-Shell Interoperability

## Problem

When you have multiple shells (fish, bash, zsh) configured, switching between them can break:
- Command history isolation and search
- Tab completion context
- Shell-specific key bindings
- Environment variable consistency

This guide shows how to maintain full functionality across all shells.

## Shell Architecture in Dotfiles

**Primary shell:** `fish` (default interactive shell, excellent defaults)
**Secondary shells:** `bash`, `zsh` (for compatibility, scripts, or terminal multiplexers)

## History Management

Each shell maintains separate history:

- **Fish:** `~/.local/share/fish/fish_history` (proprietary SQLite format)
- **Bash:** `~/.bash_history` (plaintext, line-per-command)
- **Zsh:** `~/.zsh_history` (plaintext or Zsh extended format)

### Design Decision: Separate Histories

Keep histories separate. This is safer because:
1. Each shell's history format is optimized for that shell
2. Fish history includes command runtime, exit status, and working directory
3. Cross-shell history synchronization is fragile
4. Separate histories avoid corruption from incompatible shell writes

### Bash History Best Practices

When calling bash from fish, ensure:

1. **HISTFILE is set correctly**
   ```bash
   export HISTFILE="$HOME/.bash_history"
   ```

2. **History is saved immediately** (not just on exit)
   ```bash
   export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
   ```

3. **History size is reasonable**
   ```bash
   export HISTSIZE=5000
   export HISTFILESIZE=10000
   ```

## Use Case 1: Quick Bash Session from Fish

### Basic Approach

Type in fish:
```fish
bash
```

This works, but bash starts with a minimal environment. To get all features:

### Enhanced Approach with Wrapper Function

The dotfiles include pre-built fish launcher functions in `fish/conf.d/shell-launchers.fish`. These wrap bash/zsh with proper environment setup:

```fish
# Already included in dotfiles; just source it:
source ~/.config/fish/conf.d/shell-launchers.fish

# Now you can use:
bash        # Standard bash with history/environment
bash-full   # Extended bash session (login shell)
zsh         # Zsh with environment setup
```

Or if you want to create your own wrapper:

```fish
# ~/.config/fish/conf.d/bash-wrapper.fish
function to-bash --description 'Launch bash with full environment setup'
    set -lx HISTFILE "$HOME/.bash_history"
    set -lx PROMPT_COMMAND 'history -a; history -n'
    /usr/bin/bash $argv
end

# Alias for convenience
alias bash=to-bash
```

Key points:
1. Use a custom function name (`to-bash` not `bash`) to avoid shadowing the external command
2. Create an alias (`alias bash=to-bash`) so typing `bash` works naturally
3. Use absolute path (`/usr/bin/bash`) instead of `command bash`
4. Set HISTFILE to `~/.bash_history` for multi-session history sync
5. Set PROMPT_COMMAND to `'history -a; history -n'` to append and read history immediately
3. Bash reads new history from file before prompt (shared history across bash sessions)
4. You get full history access in bash

### Example Session

```fish
$ bash
bash-5.2$ echo "test"
test
bash-5.2$ history
    1  echo "test"
bash-5.2$ exit
$ history | grep "test"
# Returns fish history with "echo test"
```

## Use Case 2: Bash with Full Interactive Features

Some users want bash with all features enabled when running longer sessions.

### Comprehensive Bash Launcher Function

```fish
# ~/.config/fish/conf.d/bash-launcher.fish

function bash-full --wraps bash --description 'Launch bash with comprehensive environment'
    set -lx SHELL /bin/bash
    set -lx HISTFILE "$HOME/.bash_history"
    set -lx PROMPT_COMMAND 'history -a; history -n'
    set -lx HISTSIZE 5000
    set -lx HISTFILESIZE 10000
    set -lx HISTCONTROL 'ignoreboth:erasedups'
    set -lx TERM xterm-256color
    set -lx EDITOR nvim
    set -lx VISUAL nvim
    
    # Preserve current directory
    builtin cd (pwd)
    
    command bash --login "$argv"
end
```

Usage:
```fish
bash-full
```

## Use Case 3: Indicating Active Shell in Prompt

When you switch shells, it's useful to see which shell you're in.

### Fish Prompt Indicator

Add to `~/.config/fish/config.fish`:

```fish
# Show shell indicator in prompt
function fish_prompt
    set_color brgreen
    echo -n "🐠 fish "
    set_color normal
    # Rest of your prompt...
end
```

### Bash Prompt Indicator

Add to `~/.bashrc`:

```bash
# Bash shell indicator in prompt
if [[ "$PS1" == *"bash"* ]]; then
    PS1='\[\033[1;35m\]🐚 bash\[\033[0m\] \[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='\[\033[1;35m\]🐚 bash\[\033[0m\] \u@\h:\w\$ '
fi
```

### Zsh Prompt Indicator

Add to `~/.config/zsh/.zshrc`:

```zsh
# Zsh shell indicator in prompt
# If using a theme/prompt framework, add:
prompt_setup() {
    # Prepend shell indicator to existing prompt
    PROMPT="%F{135}⚙️ zsh%f $PROMPT"
}
```

## Use Case 4: Bash as Default Shell for Scripting

If you use Fedora and some systemd services or scripts expect bash:

```bash
# In ~/.bashrc, auto-detect context
if [[ "$SHELL" == "/usr/bin/fish" ]]; then
    # Called from fish: minimal setup, assume fish already configured env
    true
else
    # Called directly: full setup needed
    export PATH="$HOME/.local/bin:$PATH"
    export EDITOR=nvim
    export VISUAL=nvim
fi
```

## Use Case 5: Tmux with Multiple Shells

Tmux sessions persist across shell switches. Setup each pane with the correct shell:

```bash
# In tmux pane, switch to fish:
exec fish

# In tmux pane, switch to bash:
exec bash

# Or create new window in specific shell:
tmux new-window -t mywindow -c '/current/dir' 'bash'
```

**Note:** Use `exec` to replace the current shell (cleaner than spawning subshells).

## Environment Variables Across Shells

Maintain `~/.profile` as single source of truth for login/environment variables:

```bash
# ~/.profile - sourced by bash, zsh, and fish
export PATH="$HOME/.local/bin:$PATH"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export EDITOR=nvim
export VISUAL=nvim
export TERM=xterm-256color
```

Then in each shell's RC file:

**Bash (.bashrc):**
```bash
[[ -s "$HOME/.profile" ]] && source "$HOME/.profile"
```

**Zsh (.zshrc):**
```zsh
[[ -s "$HOME/.profile" ]] && source "$HOME/.profile"
```

**Fish (config.fish):**
```fish
test -s "$HOME/.profile" && source "$HOME/.profile"
```

## Tab Completion Across Shells

### Fish Completion System

Fish auto-generates completions from man pages and has excellent defaults. Nothing extra needed.

Add custom completions if needed:
```bash
# ~/.config/fish/completions/mycommand.fish
complete -c mycommand -s f -l file -d "Input file"
```

### Bash Completion System

Enable bash-completion package:
```bash
sudo dnf install -y bash-completion
```

Source it in ~/.bashrc:
```bash
if [ -f /etc/bash_completion ]; then
    source /etc/bash_completion
fi
```

### Zsh Completion System

Zsh has built-in completion that's very powerful:

```zsh
# In .zshrc
autoload -U compinit
compinit -C

# Enable completion caching
zstyle ':completion::complete:*' use-cache on

# Ignore remote machines when completing
zstyle ':completion:*:(ssh|scp):*' hosts off
```

## Troubleshooting

### Problem: Bash history not persisting

**Solution:** Check HISTFILE and add to ~/.bashrc:
```bash
export HISTFILE="$HOME/.bash_history"
export PROMPT_COMMAND="history -a; history -n"
```

### Problem: Shell switching loses PWD (current directory)

**Solution:** When using `exec` to switch shells, current directory is preserved automatically. If using subshell, add:
```fish
builtin cd (pwd)
bash
```

### Problem: Completion doesn't work in bash

**Solution:** Install bash-completion and source it:
```bash
sudo dnf install -y bash-completion
source /usr/share/bash-completion/bash_completion
```

### Problem: Environment variables missing in subshell

**Solution:** Source ~/.profile in each shell's RC file. Verify with:
```bash
bash -c 'echo $EDITOR'  # Should show 'nvim'
fish -c 'echo $EDITOR' # Should show 'nvim'
```

## Quick Reference

### Switching Shells from Fish

```fish
# Quick launch bash
bash

# Launch bash with full setup
bash-full

# Launch zsh
zsh

# Launch bash as login shell
bash -l

# Launch bash with specific script
bash ~/script.sh
```

### Viewing History Across Shells

```fish
# Fish history (built-in)
history          # Interactive search
history search   # Search for specific command

# Bash history
bash -c 'history'

# Zsh history
zsh -c 'history'

# View raw bash history file
cat ~/.bash_history

# View raw zsh history file
cat ~/.zsh_history
```

## Related Configuration Files

- `~/.config/fish/config.fish` - Fish shell configuration
- `~/.bashrc` - Bash interactive shell
- `~/.bash_profile` - Bash login shell
- `~/.config/zsh/.zshrc` - Zsh interactive shell
- `~/.profile` - Shared environment (sourced by all shells)
- `~/.bash_history` - Bash history (plaintext)
- `~/.local/share/fish/fish_history` - Fish history (SQLite)
- `~/.zsh_history` - Zsh history

## Further Reading

- [Fish Shell Documentation](https://fishshell.com/docs/current/)
- [Bash Manual](https://www.gnu.org/software/bash/manual/)
- [Zsh Manual](http://zsh.sourceforge.net/Doc/)
- [Shell History Article](https://www.gnu.org/software/bash/manual/html_node/Bash-History-Facilities.html)
