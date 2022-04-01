source "$XDG_CONFIG_HOME/zsh/aliases"

setopt AUTO_PARAM_SLASH
unsetopt CASE_GLOB

#initialize completion system
autoload -U compinit; compinit
#autocomplete hidden files
_comp_options+=(globdots)
#source "$HOME/dotfiles/zsh/external/completion.zsh"
source "$DOTFILES/zsh/external/completion.zsh"

#make sure external stuff is loaded by zsh
fpath=($ZDOTDIR/external $fpath)

autoload -Uz prompt_purification_setup; prompt_purification_setup

#push the current directory visisted on to the stack
setopt AUTO_PUSHD
#do not store duplicate directories in the stack
setopt PUSHD_IGNORE_DUPS
#do not print the directory stack after using pushd pr popd
setopt PUSHD_SILENT

#enable vi mode
bindkey -v
export KEYTIMEOUT=1
autoload -Uz cursor_mode && cursor_mode
zmodload zsh/complist
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'h' vi-backward-char
