#!/bin/bash

#
# install.sh setup dotfiles repo
#
# Valid for Platform:
# - ArchLinux
# - Ubuntu (server)
# - Fedora (todo)
#

# make sure xdg path and dotfiles repo is found
# alternative is to set it directly here using ~/.config
# might be best solution!
if [ ! $XDG_CONFIG_HOME ]; then
  echo "Warning need to make sure XDG_CONFIG_HOME is set"
  XDG_CONFIG_HOME="$HOME/.config"
fi
if [ ! $XDG_DATA_HOME ]; then
  echo "Warning need to make sure XDG_DATA_HOME is set"
  XDG_DATA_HOME="$XDG_CONFIG_HOME/local/share"
fi
if [ ! $DOTFILES ]; then
  echo "Warning need to make sure DOTFILES is set"
  DOTFILES="$HOME/dotfiles"
fi

# share entire X11 directory
rm -rf "$HOME/.config/X11"
ln -s "$DOTFILES/X11" "$HOME/.config"

######
# i3 #
######

rm -rf "$HOME/.config/i3"
ln -s "$DOTFILES/i3" "$HOME/.config"

#######
# zsh #
#######
mkdir -p "$HOME/.config/zsh"
ln -sf "$DOTFILES/zsh/.zshenv" "$HOME"
ln -sf "$DOTFILES/zsh/.zshrc" "$HOME/.config/zsh"

ln -sf "$DOTFILES/zsh/aliases" "$HOME/.config/zsh"

#make sure entire folder external is symlinked
rm -rf "$HOME/.config/zsh/external"
ln -sf "$DOTFILES/zsh/external" "$HOME/.config/zsh"

#SpaceVim global config
rm -rf "$HOME/.SpaceVim.d"
ln -sf "$DOTFILES/spacevim/.SpaceVim.d" "$HOME/"

#########
# Fonts #
#########

mkdir -p "$XDG_DATA_HOME"
cp -rf "$DOTFILES/fonts" "$XDG_DATA_HOME"

#dunst notification system
mkdir -p "$XDG_CONFIG_HOME/dunst"
ln -sf "$DOTFILES/dunst/dunstrc" "$XDG_CONFIG_HOME/dunst/dunstrc"

#######
# git #
#######

mkdir -p "$XDG_CONFIG_HOME/git"
ln -sf "$DOTFILES/git/config" "$XDG_CONFIG_HOME/git/config"

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

########
# dhex #
########

rm -f "$HOME/.dhexrc"
ln -sf "$DOTFILES/dhex/.dhexrc" "$HOME"

###############
# qutebrowser #
###############

if [ -d "$XDG_CONFIG_HOME/qutebrowser" ]; then
  rm -f "$XDG_CONFIG_HOME/qutebrowser/config.py"
  ln -sf "$DOTFILES/qutebrowser/config.py" "$XDG_CONFIG_HOME/qutebrowser/"
fi

