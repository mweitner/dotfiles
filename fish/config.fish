# Fedora + Sway shell defaults
set -g fish_greeting

# Keep local scripts first in PATH
if test -d "$HOME/.local/bin"
    fish_add_path -m "$HOME/.local/bin"
end

# Tool defaults
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx PAGER less

# Match target terminal behavior used in previous zsh setup.
set -gx TERM xterm-256color

# Useful aliases
alias ll='ls -lah'
alias d='dirs -v'
alias vi='nvim'
alias vim='nvim'
alias gs='git status -sb'
alias gl='git log --decorate --oneline --graph --all'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias mc='EDITOR=nvim . /usr/lib/mc/mc-wrapper.sh'
alias python='python3'

# Quick directory stack jump aliases (1..9) like zsh setup.
for i in (seq 1 9)
    alias $i="cd +$i"
end

# Enable vi key bindings globally.
fish_vi_key_bindings
set -g fish_cursor_default block
set -g fish_cursor_insert line
set -g fish_cursor_visual block
set -g fish_cursor_replace_one underscore

# Customize key bindings to preserve your tmux workflow.
function fish_user_key_bindings
    fish_vi_key_bindings

    # Keep Ctrl-l free for tmux pane navigation; use Ctrl-g to clear screen.
    bind -M default \cg 'clear; commandline -f repaint'
    bind -M insert \cg 'clear; commandline -f repaint'

    # Better history navigation from insert mode.
    bind -M insert \ck up-or-search
    bind -M insert \cj down-or-search
    bind -M insert \cr history-pager

    # vi-style history search entry points in command mode.
    bind -M default / history-pager
    bind -M default ? history-pager
end

# Enable fzf key bindings/completions when available.
if command -q fzf
    fzf --fish | source
end

# zoxide gives fast jump navigation and complements vi-style shell usage.
if command -q zoxide
    zoxide init fish | source
end

# Helper functions ported from previous zsh workflow.
function compress --description 'Create tar.gz archive from a directory'
    if test -z "$argv[1]"
        echo "usage: compress <directory>"
        return 1
    end
    tar cvzf "$argv[1].tar.gz" "$argv[1]"
end

function wikipedia --description 'Search Wikipedia in qutebrowser'
    qutebrowser "https://en.wikipedia.org/wiki?search=$argv"
end

function duckduckgo --description 'Search DuckDuckGo in qutebrowser'
    qutebrowser "https://lite.duckduckgo.com/lite/?q=$argv"
end

function setupwifi --description 'Rename wlan device to wlan0 for legacy scripts'
    set -l wifi_index 1
    if test -n "$argv[1]"
        set wifi_index "$argv[1]"
    end

    set -l wifi_device_name "wlan$wifi_index"
    sudo ip link set down "$wifi_device_name"
    sudo ip link set "$wifi_device_name" name wlan0
    sudo ip link set up wlan0
end
