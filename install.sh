#!/bin/bash

# share entire X11 directory
rm -rf "$HOME/.config/X11"
ln -s "$HOME/dotfiles/X11" "$HOME/.config"

######
# i3 #
######

rm -rf "$HOME/.config/i3"
ln -s "$HOME/dotfiles/i3" "$HOME/.config"

#######
# zsh #
#######
mkdir -p "$HOME/.config/zsh"
ln -sf "$HOME/dotfiles/zsh/.zshenv" "$HOME"
ln -sf "$HOME/dotfiles/zsh/.zshrc" "$HOME/.config/zsh"

ln -sf "$HOME/dotfiles/zsh/aliases" "$HOME/.config/zsh"

#make sure entire folder external is symlinked
rm -rf "$HOME/.config/zsh/external"
ln -sf "$HOME/dotfiles/zsh/external" "$HOME/.config/zsh"

#SpaceVim global config
rm -rf "$HOME/.SpaceVim.d"
ln -sf "$HOME/dotfiles/spacevim/.SpaceVim.d" "$HOME/"

