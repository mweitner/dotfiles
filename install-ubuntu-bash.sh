#!/bin/bash

if [ ! $XDG_CONFIG_HOME ]; then
  XDG_CONFIG_HOME="$HOME/.config"
fi
if [ ! $DOTFILES ]; then
  DOTFILES="$HOME/dotfiles"
fi

#########
# shell #
#########

ln -sf "$HOME/dotfiles/shell/.profile" "$HOME/.profile"

########
# bash #
########

ln -sf $HOME/dotfiles/bash/.bash_aliases $HOME/.bash_aliases
ln -sf $HOME/dotfiles/bash/.bash_profile $HOME/.bash_profile
ln -sf $HOME/dotfiles/bash/.bashrc $HOME/.bashrc

#######
# git #
#######

#mkdir -p "$XDG_CONFIG_HOME/git"
#ln -sf "$DOTFILES/git/config" "$XDG_CONFIG_HOME/git/config"

######
# i3 #
######

rm -rf "$HOME/.config/i3"
ln -s "$DOTFILES/i3" "$HOME/.config"

#########################
#SpaceVim global config #
#########################

rm -rf "$HOME/.SpaceVim.d"
ln -sf "$DOTFILES/spacevim/.SpaceVim.d" "$HOME/"

##################
# tmux and tmuxp #
##################

mkdir -p "$XDG_CONFIG_HOME/tmux"
ln -sf "$DOTFILES/tmux/tmux.conf" "$XDG_CONFIG_HOME/tmux/tmux.conf"

[ ! -d "$XDG_CONFIG_HOME/tmux/plugins/tpm" ] \
&& git clone https://github.com/tmux-plugins/tpm \
"$XDG_CONFIG_HOME/tmux/plugins/tpm"

#share entire tmuxp folder
rm -rf "$XDG_CONFIG_HOME/tmuxp"
ln -sf "$DOTFILES/tmuxp" "$XDG_CONFIG_HOME"

