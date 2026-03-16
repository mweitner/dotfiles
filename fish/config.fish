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

# Useful aliases
alias ll='ls -lah'
alias gs='git status -sb'
alias gl='git log --oneline --decorate --graph -20'

# Enable vi key bindings (matches your vim workflow)
fish_vi_key_bindings

# Enable fzf keybindings/completions when available
if command -q fzf
    fzf --fish | source
end
