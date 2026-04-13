# ~/.bash_aliases - bash-specific aliases
# Sourced by ~/.bashrc

# Editor/Vi aliases (vim -> nvim)
alias vi='nvim'
alias vim='nvim'

# File listing
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

# Directory stack (like zsh)
alias d='dirs -v'
alias 1='cd +'1
alias 2='cd +'2
alias 3='cd +'3
alias 4='cd +'4
alias 5='cd +'5
alias 6='cd +'6
alias 7='cd +'7
alias 8='cd +'8
alias 9='cd +'9

# Git shortcuts
alias gs='git status -sb'
alias gl='git log --decorate --oneline --graph -20'
alias ga='git add'
alias gc='git commit'
alias gp='git push'

# Python
alias python='python3'

# Midnight Commander
alias mc='EDITOR=nvim . /usr/lib/mc/mc-wrapper.sh'

# Alert alias for long-running commands
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')}"'

