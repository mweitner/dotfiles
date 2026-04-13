#!/usr/bin/env fish
# Fish shell helpers for launching bash/zsh with full environment setup
# Place in ~/.config/fish/conf.d/ and it will auto-load
# These wrappers preserve environment and history across shell switches

# Wrapper for launching bash with proper environment setup
# Note: We use a custom name to avoid shadowing issues with fish's bash function override
function to-bash --wraps bash --description 'Launch bash with fish environment'
    # Ensure bash uses the standard history file
    set -lx HISTFILE "$HOME/.bash_history"
    
    # Save/sync history immediately (not just on shell exit)
    set -lx PROMPT_COMMAND 'history -a; history -n'
    
    # Standard bash history settings
    set -lx HISTSIZE 5000
    set -lx HISTFILESIZE 10000
    set -lx HISTCONTROL ignoreboth:erasedups
    
    # Ensure editor/pager are set
    set -lx EDITOR nvim
    set -lx VISUAL nvim
    set -lx PAGER less
    
    # Terminal environment
    set -lx TERM xterm-256color
    
    # Use absolute path to avoid fish function shadowing issues
    /usr/bin/bash $argv
end

# Alias 'bash' to our wrapper for convenience
alias bash=to-bash

# Full-featured bash launcher for longer sessions
function bash-full --wraps bash --description 'Launch bash with comprehensive setup'
    # All bash environment variables
    set -lx SHELL /bin/bash
    set -lx HISTFILE "$HOME/.bash_history"
    set -lx PROMPT_COMMAND 'history -a; history -n'
    set -lx HISTSIZE 5000
    set -lx HISTFILESIZE 10000
    set -lx HISTCONTROL ignoreboth:erasedups
    
    # Full environment
    set -lx EDITOR nvim
    set -lx VISUAL nvim
    set -lx PAGER less
    set -lx TERM xterm-256color
    
    # XDG Base Directories
    set -lx XDG_CONFIG_HOME "$HOME/.config"
    set -lx XDG_DATA_HOME "$HOME/.local/share"
    set -lx XDG_CACHE_HOME "$HOME/.cache"
    
    # Preserve current directory and launch as login shell
    builtin cd (pwd)
    /usr/bin/bash --login $argv
end

# Zsh launcher for switching to zsh with environment setup
function to-zsh --wraps zsh --description 'Launch zsh with fish environment'
    # Zsh history settings
    set -lx HISTFILE "$HOME/.zsh_history"
    set -lx HISTSIZE 5000
    set -lx SAVEHIST 10000
    
    # Environment
    set -lx EDITOR nvim
    set -lx VISUAL nvim
    set -lx PAGER less
    set -lx TERM xterm-256color
    
    # Use absolute path to avoid fish function shadowing issues
    /usr/bin/zsh $argv
end

# Alias 'zsh' to our wrapper for convenience
alias zsh=to-zsh

# Helper to show which shell you're currently in
function which-shell --description 'Display current shell info'
    echo "Current shell: $SHELL"
    set -l shell_basename (basename $SHELL)
    set -l shell_path (command -v $shell_basename)
    echo "Shell executable: $shell_path"
    $shell_basename --version | head -n1
end

# Helper to list available shells and descriptions
function list-shells --description 'List available shells with descriptions'
    echo "Available shells on this system:"
    echo ""
    if command -q fish
        echo "  fish (current)  - Default shell (primary, excellent completion, discovery)"
    end
    if command -q bash
        echo "  bash            - POSIX shell (compatibility, scripts)"
        echo "                    → bash-full for extended sessions"
        echo "                    → Invoke with: bash"
    end
    if command -q zsh
        echo "  zsh             - Powerful shell (vi mode, completion, themes)"
        echo "                    → Invoke with: zsh"
    end
    echo ""
    echo "Usage:"
    echo "  bash        # Switch to bash with pre-configured environment"
    echo "  bash-full   # Extended bash session (login shell)"
    echo "  zsh         # Switch to zsh with environment"
    echo ""
    echo "Return to fish with: exit"
end
