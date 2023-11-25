#for dotfiles
export XDG_CONFIG_HOME="$HOME/.config"

#for specific data
export XDG_DATA_HOME="$XDG_CONFIG_HOME/local/share"

#for cached files
export XDG_CACHE_HOME="$XDG_CONFIG_HOME/cache"

#make sure we launch favorite editor
export EDITOR="nvim"
export VISUAL="nvim"

#zsh config location
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

#history file path
export HISTFILE="$ZDOTDIR/.zhistory"
#maximum events for internal history
export HISTSIZE=10000
#maximum events in history file
export SAVEHIST=10000

export DOTFILES="$HOME/dotfiles"

export FZF_DEFAULT_COMMAND="rg --files --hidden --glob '!.git'"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

. "$HOME/.cargo/env"
