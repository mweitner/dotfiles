source "$XDG_CONFIG_HOME/zsh/aliases"

setopt AUTO_PARAM_SLASH
unsetopt CASE_GLOB

#make sure external stuff is loaded by zsh
fpath=($ZDOTDIR/external $fpath)

#enable vi mode
bindkey -v
export KEYTIMEOUT=1
autoload -Uz cursor_mode && cursor_mode
#need to be set before autoload compinit
zmodload zsh/complist
bindkey -M menuselect 'h' vi-backward-char
bindkey -M menuselect 'k' vi-up-line-or-history
bindkey -M menuselect 'l' vi-forward-char  
bindkey -M menuselect 'j' vi-down-line-or-history 

#remap clear-screen as Ctrl-l is used by tmux to navigate pane left
bindkey -r '^l'
bindkey -r '^g'
bindkey -s '^g' "\nclear\n"

#initialize completion system
autoload -U compinit; compinit
#autocomplete hidden files
_comp_options+=(globdots)
#source "$HOME/dotfiles/zsh/external/completion.zsh"
source "$DOTFILES/zsh/external/completion.zsh"

autoload -Uz prompt_purification_setup; prompt_purification_setup

#push the current directory visisted on to the stack
setopt AUTO_PUSHD
#do not store duplicate directories in the stack
setopt PUSHD_IGNORE_DUPS
#do not print the directory stack after using pushd pr popd
setopt PUSHD_SILENT

#editing commands with system EDITOR
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd v edit-command-line

#enable fzf
if [ $(command -v "fzf") ]; then
  if [ -f "/usr/share/fzf/completion.zsh" ]; then
    source /usr/share/fzf/completion.zsh
  fi
  if [ -f "/usr/share/fzf/key-bindings.zsh" ]; then
    source /usr/share/fzf/key-bindings.zsh
  fi
  #ubuntu installation stores it at /usr/share/doc/fzf/examples/
  if [ -f "/usr/share/doc/fzf/examples/completion.zsh" ]; then
    source /usr/share/doc/fzf/examples/completion.zsh
  fi
  if [ -f "/usr/share/doc/fzf/examples/key-bindings.zsh" ]; then
    source /usr/share/doc/fzf/examples/key-bindings.zsh
  fi
fi
#source at end to enable all above using syntax highlighting
if [ -f "/usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
#ubuntu stores zsh-syntax-highlighting at 
if [ -f "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
  source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

#source bd function jumping to parent folders
source "$DOTFILES/zsh/external/bd.zsh"
#source custom scripts
source "$DOTFILES/zsh/scripts.sh"

#start i3
if [ "$(tty)" = "/dev/tty1" ]; then
  pgrep i3 || exec startx "$XDG_CONFIG_HOME/X11/.xinitrc"
fi

if [ ! "$(tty)" = "/dev/tty1" ]; then
  #always list tmuxp sessions
  #ftmuxp
fi

